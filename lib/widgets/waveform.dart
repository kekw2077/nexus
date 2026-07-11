import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Визуализатор голоса. Полосы сдвигаются справа налево: новая амплитуда
/// входит с правого края. Когда неактивен — ровная тихая линия.
///
/// Источник амплитуды сейчас синтетический (_sample). Реальная версия
/// заменит его на RMS из микрофонного потока — форма виджета не изменится.
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
  Timer? _timer;

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
    _timer?.cancel();
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!widget.active || reduceMotion) {
      setState(() => _levels = List.filled(widget.barCount, _idle));
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      final amp = _sample(DateTime.now().millisecondsSinceEpoch) * widget.sensitivity;
      setState(() {
        _levels = [..._levels.skip(1), max(_idle, amp.clamp(0.0, 1.0))];
      });
    });
  }

  double _sample(int t) {
    final slow = sin(t / 380) * 0.3 + 0.45;
    final fast = sin(t / 90) * 0.18;
    final jitter = (sin(t * 12.9898) * 43758.5453) % 1;
    return (slow + fast + jitter.abs() * 0.15).clamp(_idle, 1.0);
  }

  @override
  void dispose() {
    _timer?.cancel();
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
