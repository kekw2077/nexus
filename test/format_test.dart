import 'package:evs_remote/core/format.dart';
import 'package:evs_remote/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatUptime', () {
    test('минуты', () => expect(formatUptime(300), '5 мин'));
    test('часы и минуты', () => expect(formatUptime(3660), '1 ч 1 мин'));
    test('дни с падежом', () => expect(formatUptime(86400 * 2 + 3600), '2 дня 1 ч'));
    test('пять дней', () => expect(formatUptime(86400 * 5), '5 дней 0 ч'));
  });

  group('formatBytes', () {
    test('гигабайты', () => expect(formatBytes(16 * 1024 * 1024 * 1024), '16 ГБ'));
    test('мегабайты', () => expect(formatBytes(512 * 1024 * 1024), '512 МБ'));
  });

  group('validators', () {
    test('корректный MAC', () => expect(isValidMac('00:1A:2B:3C:4D:5E'), isTrue));
    test('MAC с дефисами', () => expect(isValidMac('00-1a-2b-3c-4d-5e'), isTrue));
    test('битый MAC', () => expect(isValidMac('00:1A:2B:3C:4D'), isFalse));
    test('нормализация MAC', () => expect(normalizeMac('00-1a-2b-3c-4d-5e'), '00:1A:2B:3C:4D:5E'));

    test('IPv4', () => expect(isValidHost('192.168.1.10'), isTrue));
    test('октет > 255', () => expect(isValidHost('192.168.1.300'), isFalse));
    test('MagicDNS-имя', () => expect(isValidHost('server.tail1234.ts.net'), isTrue));

    test('порт в диапазоне', () => expect(isValidPort('8765'), isTrue));
    test('порт вне диапазона', () => expect(isValidPort('70000'), isFalse));
  });
}
