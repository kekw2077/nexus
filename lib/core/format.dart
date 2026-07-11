/// Человекочитаемое форматирование. Русские формы без внешних зависимостей.

String formatRelative(DateTime? time) {
  if (time == null) return 'ещё не включался';
  final diff = DateTime.now().difference(time);
  if (diff.isNegative) return 'только что';

  final minutes = diff.inMinutes;
  if (minutes < 1) return 'только что';
  if (minutes < 60) return '$minutes ${_plural(minutes, 'минуту', 'минуты', 'минут')} назад';

  final hours = diff.inHours;
  if (hours < 24) return '$hours ${_plural(hours, 'час', 'часа', 'часов')} назад';

  final days = diff.inDays;
  return '$days ${_plural(days, 'день', 'дня', 'дней')} назад';
}

String formatUptime(int seconds) {
  final days = seconds ~/ 86400;
  final hours = (seconds % 86400) ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;

  if (days > 0) {
    return '$days ${_plural(days, 'день', 'дня', 'дней')} $hours ч';
  }
  if (hours > 0) return '$hours ч $minutes мин';
  return '$minutes мин';
}

String formatBytes(int bytes) {
  const units = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final isWhole = value == value.roundToDouble();
  final rounded = value >= 100 || unit == 0 || isWhole
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return '$rounded ${units[unit]}';
}

/// Выбор падежной формы русского существительного по числу.
String _plural(int n, String one, String few, String many) {
  final mod100 = n % 100;
  final mod10 = n % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}
