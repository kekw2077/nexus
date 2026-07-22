import 'package:evs_remote/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateService.isNewer', () {
    test('patch выше', () => expect(UpdateService.isNewer('0.1.1', '0.1.0'), isTrue));
    test('minor выше', () => expect(UpdateService.isNewer('0.2.0', '0.1.9'), isTrue));
    test('major выше', () => expect(UpdateService.isNewer('1.0.0', '0.9.9'), isTrue));
    test('равные — не новее', () => expect(UpdateService.isNewer('0.1.0', '0.1.0'), isFalse));
    test('ниже — не новее', () => expect(UpdateService.isNewer('0.1.0', '0.2.0'), isFalse));

    test('префикс v игнорируется', () => expect(UpdateService.isNewer('v0.2.0', '0.1.0'), isTrue));
    test('build-суффикс игнорируется', () => expect(UpdateService.isNewer('0.1.0+5', '0.1.0+1'), isFalse));
    test('pre-release суффикс отбрасывается', () => expect(UpdateService.isNewer('0.2.0-beta', '0.1.0'), isTrue));
    test('короткая версия дополняется нулями', () => expect(UpdateService.isNewer('1', '0.9.9'), isTrue));
  });
}
