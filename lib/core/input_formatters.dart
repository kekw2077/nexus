import 'package:flutter/services.dart';

/// Форматирует ввод MAC на лету: оставляет только hex, переводит в верхний
/// регистр, расставляет двоеточия каждые 2 символа и ограничивает 6 группами
/// (00:1A:2B:3C:4D:5E). Курсор держит в конце — для короткого поля этого хватает.
class MacInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final hex = newValue.text.toUpperCase().replaceAll(RegExp('[^0-9A-F]'), '');
    final capped = hex.length > 12 ? hex.substring(0, 12) : hex;

    final buf = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i != 0 && i.isEven) buf.write(':');
      buf.write(capped[i]);
    }

    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
