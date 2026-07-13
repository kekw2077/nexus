import 'package:evs_remote/services/network_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('subnetBase24', () {
    test('обычный IPv4', () => expect(subnetBase24('192.168.1.37'), '192.168.1.'));
    test('другая подсеть', () => expect(subnetBase24('10.0.0.5'), '10.0.0.'));
    test('не IP', () => expect(subnetBase24('server.local'), isNull));
    test('октет вне диапазона', () => expect(subnetBase24('1.2.3.999'), isNull));
    test('мало октетов', () => expect(subnetBase24('192.168.1'), isNull));
  });

  group('ipSortKey', () {
    test('числовой порядок, не лексикографический', () {
      expect(ipSortKey('192.168.1.2') < ipSortKey('192.168.1.10'), isTrue);
    });

    test('разные подсети упорядочены', () {
      expect(ipSortKey('192.168.0.254') < ipSortKey('192.168.1.1'), isTrue);
    });
  });

  group('DiscoveredHost.label', () {
    test('показывает hostname, если есть', () {
      expect(DiscoveredHost(ip: '192.168.1.5', port: 8765, hostname: 'nas').label, 'nas');
    });

    test('падает обратно на IP', () {
      expect(DiscoveredHost(ip: '192.168.1.5', port: 8765).label, '192.168.1.5');
    });
  });
}
