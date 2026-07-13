/// Состояние карточки. booting — окно между отправкой magic-пакета
/// и первым успешным ответом /health.
enum HostState { online, offline, booting, unknown }

/// Один физический диск/том: имя (точка монтирования или буква), заполненность.
class DiskInfo {
  const DiskInfo({
    required this.name,
    required this.percent,
    this.totalBytes,
    this.usedBytes,
  });

  final String name;
  final int percent;
  final int? totalBytes;
  final int? usedBytes;

  factory DiskInfo.fromJson(Map<String, dynamic> json) {
    return DiskInfo(
      name: (json['name'] ?? json['mount'] ?? json['mountpoint'] ?? 'Диск') as String,
      percent: (json['percent'] as num?)?.round() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt(),
      usedBytes: (json['usedBytes'] as num?)?.toInt(),
    );
  }
}

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
    this.disks = const [],
    this.cpuTemp,
    this.gpuTemp,
    this.gpuUtil,
    this.vramUsedBytes,
    this.vramTotalBytes,
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

  /// Все физические диски системы. Пусто у старых агентов — тогда карточка
  /// показывает единственный диск из legacy-поля [disk] (см. fromJson).
  final List<DiskInfo> disks;

  /// Температуры ЦП и ГП по отдельности (null — датчик недоступен).
  final double? cpuTemp;
  final double? gpuTemp;

  /// Загрузка GPU в % и видеопамять в байтах (null — нет GPU/nvidia-smi).
  final int? gpuUtil;
  final int? vramUsedBytes;
  final int? vramTotalBytes;

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
        disks = const [],
        cpuTemp = null,
        gpuTemp = null,
        gpuUtil = null,
        vramUsedBytes = null,
        vramTotalBytes = null,
        checkedAt = _epoch;

  factory HostMetrics.fromJson(Map<String, dynamic> json) {
    final rawDisks = json['disks'] as List?;
    final disks = rawDisks != null
        ? rawDisks
            .whereType<Map<String, dynamic>>()
            .map(DiskInfo.fromJson)
            .toList()
        : <DiskInfo>[
            // Старый агент: один диск в legacy-полях — заворачиваем в список.
            DiskInfo(
              name: 'Диск',
              percent: (json['disk'] as num?)?.round() ?? 0,
              totalBytes: (json['diskTotalBytes'] as num?)?.toInt(),
            ),
          ];

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
      disks: disks,
      cpuTemp: (json['cpuTemp'] as num?)?.toDouble(),
      gpuTemp: (json['gpuTemp'] as num?)?.toDouble(),
      gpuUtil: (json['gpu'] as num?)?.round(),
      vramUsedBytes: (json['vramUsedBytes'] as num?)?.toInt(),
      vramTotalBytes: (json['vramTotalBytes'] as num?)?.toInt(),
      checkedAt: DateTime.now(),
    );
  }
}
