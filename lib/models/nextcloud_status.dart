/// Состояние Nextcloud, собранное агентом на сервере (status.php + serverinfo).
/// configured=false — облако у агента не настроено (карточку показывать не нужно).
/// hasServerinfo=false — доступен только status.php, подробной статистики нет.
class NextcloudStatus {
  const NextcloudStatus({
    this.configured = false,
    this.reachable = false,
    this.maintenance = false,
    this.needsDbUpgrade = false,
    this.hasServerinfo = false,
    this.version,
    this.productName,
    this.activeUsers5min,
    this.activeUsers1h,
    this.activeUsers24h,
    this.numUsers,
    this.numFiles,
    this.numShares,
    this.freeSpaceBytes,
    this.appUpdates,
  });

  final bool configured;
  final bool reachable;
  final bool maintenance;
  final bool needsDbUpgrade;
  final bool hasServerinfo;
  final String? version;
  final String? productName;
  final int? activeUsers5min;
  final int? activeUsers1h;
  final int? activeUsers24h;
  final int? numUsers;
  final int? numFiles;
  final int? numShares;
  final int? freeSpaceBytes;
  final int? appUpdates;

  bool get updateAvailable => (appUpdates ?? 0) > 0;

  factory NextcloudStatus.notConfigured() => const NextcloudStatus();

  factory NextcloudStatus.fromJson(Map<String, dynamic> json) {
    final active = json['activeUsers'] as Map<String, dynamic>?;
    return NextcloudStatus(
      configured: json['configured'] as bool? ?? false,
      reachable: json['reachable'] as bool? ?? false,
      maintenance: json['maintenance'] as bool? ?? false,
      needsDbUpgrade: json['needsDbUpgrade'] as bool? ?? false,
      hasServerinfo: json['hasServerinfo'] as bool? ?? false,
      version: json['version'] as String?,
      productName: json['productName'] as String?,
      activeUsers5min: (active?['last5min'] as num?)?.toInt(),
      activeUsers1h: (active?['last1hour'] as num?)?.toInt(),
      activeUsers24h: (active?['last24hours'] as num?)?.toInt(),
      numUsers: (json['numUsers'] as num?)?.toInt(),
      numFiles: (json['numFiles'] as num?)?.toInt(),
      numShares: (json['numShares'] as num?)?.toInt(),
      freeSpaceBytes: (json['freeSpaceBytes'] as num?)?.toInt(),
      appUpdates: (json['appUpdates'] as num?)?.toInt(),
    );
  }
}
