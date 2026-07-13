import 'package:evs_remote/core/input_formatters.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _format(String input) {
  return MacInputFormatter().formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(text: input),
  );
}

void main() {
  group('MacInputFormatter', () {
    test('расставляет двоеточия и верхний регистр', () {
      expect(_format('001a2b3c4d5e').text, '00:1A:2B:3C:4D:5E');
    });

    test('чистит мусорные символы', () {
      expect(_format('zz00:1a').text, '00:1A');
    });

    test('обрезает лишние символы до 6 групп', () {
      expect(_format('001a2b3c4d5e9999').text, '00:1A:2B:3C:4D:5E');
    });

    test('курсор в конце', () {
      final v = _format('001a2b');
      expect(v.selection.baseOffset, v.text.length);
    });

    test('частичный ввод не добавляет висячее двоеточие', () {
      expect(_format('001').text, '00:1');
    });
  });
}
