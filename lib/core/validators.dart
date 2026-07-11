/// Валидация сетевых полей. Возвращают текст ошибки или null, если поле верно —
/// удобно передавать прямо в TextFormField.validator.

final _macRe = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$');
final _hostnameRe = RegExp(
  r'^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$',
);

bool isValidMac(String value) => _macRe.hasMatch(value.trim());

String normalizeMac(String value) =>
    value.trim().replaceAll('-', ':').toUpperCase();

/// IPv4 с проверкой октетов либо имя хоста (в т.ч. MagicDNS *.ts.net).
bool isValidHost(String value) {
  final v = value.trim();
  if (v.isEmpty) return false;
  final ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
  final m = ipv4.firstMatch(v);
  if (m != null) {
    for (var i = 1; i <= 4; i++) {
      if (int.parse(m.group(i)!) > 255) return false;
    }
    return true;
  }
  return _hostnameRe.hasMatch(v);
}

bool isValidPort(String value) {
  final n = int.tryParse(value.trim());
  return n != null && n > 0 && n <= 65535;
}

String? validateName(String? value) =>
    (value == null || value.trim().isEmpty) ? 'Введите название' : null;

String? validateMac(String? value) =>
    isValidMac(value ?? '') ? null : 'Формат 00:1A:2B:3C:4D:5E';

String? validateHost(String? value) =>
    isValidHost(value ?? '') ? null : 'IP-адрес или имя хоста';

String? validatePort(String? value) =>
    isValidPort(value ?? '') ? null : 'Порт 1–65535';

/// Порог в процентах (cpu/ram/disk). Пустое значение допустимо — значит
/// «не менять», проверка не срабатывает.
String? validatePercent(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  final n = int.tryParse(v);
  return (n != null && n >= 1 && n <= 100) ? null : 'Диапазон 1–100';
}

/// Порог температуры в градусах. Пустое значение допустимо — «не менять».
String? validateTempThreshold(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  final n = double.tryParse(v);
  return (n != null && n >= 1 && n <= 150) ? null : 'Диапазон 1–150';
}
