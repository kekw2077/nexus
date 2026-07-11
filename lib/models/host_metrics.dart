/// Состояние карточки. booting — окно между отправкой magic-пакета
/// и первым успешным ответом /health.
enum HostState { online, offline, booting, unknown }

class HostMetrics {
  HostMetrics({
    required this.state,
    this.cpu = 0,
    this.ram = 0,
    this.disk = 0,
    this.temperature = 0,
    this.uptimeSec = 0,
    this.hasTemperature = false,
    this.hostname,
    this.cores,
    this.loadAvg = const [],
    this.ramTotalBytes,
    this.diskTotalBytes,
    DateTime? checkedAt,
  }) : checkedAt = checkedAt ?? _epoch;

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  final HostState state;
  final int cpu;
  final int ram;
  final int disk;
  final double temperature;
  final int uptimeSec;
  final bool hasTemperature;
  final String? hostname;
  final int? cores;
  final List<double> loadAvg;
  final int? ramTotalBytes;
  final int? diskTotalBytes;
  final DateTime checkedAt;

  bool get isOnline => state == HostState.online;

  HostMetrics.offline() : this._simple(HostState.offline);
  HostMetrics.unknown() : this._simple(HostState.unknown);
  HostMetrics.booting() : this._simple(HostState.booting);

  HostMetrics._simple(this.state)
      : cpu = 0,
        ram = 0,
        disk = 0,
        temperature = 0,
        uptimeSec = 0,
        hasTemperature = false,
        hostname = null,
        cores = null,
        loadAvg = const [],
        ramTotalBytes = null,
        diskTotalBytes = null,
        checkedAt = _epoch;

  factory HostMetrics.fromJson(Map<String, dynamic> json) {
    return HostMetrics(
      state: HostState.online,
      cpu: (json['cpu'] as num?)?.round() ?? 0,
      ram: (json['ram'] as num?)?.round() ?? 0,
      disk: (json['disk'] as num?)?.round() ?? 0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
      uptimeSec: (json['uptimeSec'] as num?)?.toInt() ?? 0,
      hasTemperature: json['hasTemperature'] as bool? ?? false,
      hostname: json['hostname'] as String?,
      cores: (json['cores'] as num?)?.toInt(),
      loadAvg: (json['loadAvg'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [],
      ramTotalBytes: (json['ramTotalBytes'] as num?)?.toInt(),
      diskTotalBytes: (json['diskTotalBytes'] as num?)?.toInt(),
      checkedAt: DateTime.now(),
    );
  }
}
