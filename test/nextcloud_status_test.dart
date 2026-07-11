import 'package:evs_remote/models/nextcloud_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NextcloudStatus', () {
    test('notConfigured — карточка скрыта', () {
      const nc = NextcloudStatus();
      expect(nc.configured, isFalse);
      expect(NextcloudStatus.notConfigured().configured, isFalse);
    });

    test('fromJson — только status.php (без serverinfo)', () {
      final nc = NextcloudStatus.fromJson({
        'configured': true,
        'reachable': true,
        'maintenance': false,
        'needsDbUpgrade': false,
        'hasServerinfo': false,
        'version': '29.0.4',
        'productName': 'Nextcloud',
      });
      expect(nc.configured, isTrue);
      expect(nc.reachable, isTrue);
      expect(nc.hasServerinfo, isFalse);
      expect(nc.version, '29.0.4');
      expect(nc.numUsers, isNull);
      expect(nc.updateAvailable, isFalse);
    });

    test('fromJson — полный serverinfo', () {
      final nc = NextcloudStatus.fromJson({
        'configured': true,
        'reachable': true,
        'maintenance': false,
        'hasServerinfo': true,
        'version': '29.0.4',
        'activeUsers': {'last5min': 2, 'last1hour': 5, 'last24hours': 12},
        'numUsers': 8,
        'numFiles': 123456,
        'numShares': 42,
        'freeSpaceBytes': 500000000000,
        'appUpdates': 3,
      });
      expect(nc.hasServerinfo, isTrue);
      expect(nc.activeUsers5min, 2);
      expect(nc.activeUsers24h, 12);
      expect(nc.numFiles, 123456);
      expect(nc.freeSpaceBytes, 500000000000);
      expect(nc.updateAvailable, isTrue);
      expect(nc.appUpdates, 3);
    });

    test('fromJson — недоступный облако', () {
      final nc = NextcloudStatus.fromJson({'configured': true, 'reachable': false});
      expect(nc.configured, isTrue);
      expect(nc.reachable, isFalse);
    });

    test('fromJson — occ-проверки и серверная техинфа', () {
      final nc = NextcloudStatus.fromJson({
        'configured': true,
        'reachable': true,
        'hasServerinfo': true,
        'coreUpdateAvailable': true,
        'coreUpdateVersion': '30.0.1',
        'warningsCount': 2,
        'warnings': ['Нет индекса БД', 'memcache не настроен'],
        'phpVersion': '8.3.2',
        'webserver': 'Apache',
        'database': 'mysql 10.11',
        'dbSizeBytes': 1048576,
      });
      expect(nc.coreUpdateAvailable, isTrue);
      expect(nc.coreUpdateVersion, '30.0.1');
      expect(nc.warningsCount, 2);
      expect(nc.warnings, hasLength(2));
      expect(nc.phpVersion, '8.3.2');
      expect(nc.database, 'mysql 10.11');
      expect(nc.dbSizeBytes, 1048576);
    });

    test('fromJson — occ/serverinfo поля отсутствуют → безопасные дефолты', () {
      final nc = NextcloudStatus.fromJson({'configured': true, 'reachable': true});
      expect(nc.coreUpdateAvailable, isFalse);
      expect(nc.warnings, isEmpty);
      expect(nc.warningsCount, isNull);
      expect(nc.phpVersion, isNull);
    });
  });
}
