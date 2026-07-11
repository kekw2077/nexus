import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

/// Визуализатор голоса. Полосы сдвигаются справа налево: новая амплитуда
/// входит с правого края. Когда неактивен — ровная тихая линия.
///
/// Амплитуда — RMS из PCM16-потока микрофона (пакет `record`). Без
/// разрешения на запись или на неподдерживаемой платформе остаётся тихая
/// линия — вызывающий код уже блокирует запуск прослушивания при !isConnected.
class Waveform extends StatefulWidget {
  const Waveform({
    super.key,
    required this.active,
    this.sensitivity = 1.0,
    this.barCount = 28,
  });

  final bool active;
  final double sensitivity;
  final int barCount;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform> {
  static const _idle = 0.08;
  late List<double> _levels;
  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;

  @override
  void initState() {
    super.initState();
    _levels = List.filled(widget.barCount, _idle);
    _maybeStart();
  }

  @override
  void didUpdateWidget(covariant Waveform old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _maybeStart();
  }

  void _maybeStart() {
    unawaited(_sub?.cancel());
    _sub = null;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!widget.active || reduceMotion) {
      setState(() => _levels = List.filled(widget.barCount, _idle));
      unawaited(_recorder.stop());
      return;
    }
    unawaited(_startStream());
  }

  Future<void> _startStream() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) setState(() => _levels = List.filled(widget.barCount, _idle));
      return;
    }
    final stream = await _recorder.startStream(
      const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1),
    );
    _sub = stream.listen(_onChunk);
  }

  void _onChunk(Uint8List chunk) {
    if (!mounted) return;
    final amp = (_rms(chunk) * widget.sensitivity).clamp(0.0, 1.0);
    setState(() {
      _levels = [..._levels.skip(1), max(_idle, amp)];
    });
  }

  double _rms(Uint8List bytes) {
    final sampleCount = bytes.length ~/ 2;
    if (sampleCount == 0) return 0;
    final data = ByteData.sublistView(bytes);
    var sumSquares = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      final sample = data.getInt16(i * 2, Endian.little) / 32768;
      sumSquares += sample * sample;
    }
    return sqrt(sumSquares / sampleCount);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(_recorder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 48,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: widget.active ? 1.0 : 0.3,
        child: CustomPaint(
          size: Size.infinite,
          painter: _WavePainter(_levels, color),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.levels, this.color);

  final List<double> levels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    const gap = 3.0;
    final barWidth = (size.width - gap * (levels.length - 1)) / levels.length;
    final paint = Paint()..color = color;

    for (var i = 0; i < levels.length; i++) {
      final h = 6 + levels[i] * (size.height - 6);
      final x = i * (barWidth + gap);
      final y = (size.height - h) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, h),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.levels != levels || old.color != color;
}
