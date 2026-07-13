import 'package:evs_remote/models/host_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HostMetrics.fromJson — диски', () {
    test('парсит список дисков', () {
      final m = HostMetrics.fromJson({
        'cpu': 10,
        'ram': 20,
        'disks': [
          {'name': '/', 'percent': 42, 'totalBytes': 500000000000},
          {'name': '/data', 'percent': 88, 'totalBytes': 2000000000000},
        ],
      });
      expect(m.disks.length, 2);
      expect(m.disks[0].name, '/');
      expect(m.disks[1].percent, 88);
    });

    test('старый агент без disks — оборачивает legacy-поле в один диск', () {
      final m = HostMetrics.fromJson({'cpu': 5, 'disk': 73, 'diskTotalBytes': 1000000000});
      expect(m.disks.length, 1);
      expect(m.disks.single.percent, 73);
      expect(m.disks.single.totalBytes, 1000000000);
    });
  });

  group('HostMetrics.fromJson — температуры', () {
    test('раздельные cpuTemp/gpuTemp', () {
      final m = HostMetrics.fromJson({'cpuTemp': 61.5, 'gpuTemp': 72});
      expect(m.cpuTemp, 61.5);
      expect(m.gpuTemp, 72);
    });

    test('нет температур — null', () {
      final m = HostMetrics.fromJson({'cpu': 1});
      expect(m.cpuTemp, isNull);
      expect(m.gpuTemp, isNull);
    });
  });
}
