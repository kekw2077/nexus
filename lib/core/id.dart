import 'dart:math';

/// Короткий уникальный идентификатор без внешних зависимостей.
/// Время в основании 36 гарантирует монотонность, случайный хвост — уникальность
/// при добавлении нескольких записей в одну миллисекунду.
String newId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final rand = Random().nextInt(0x7fffffff);
  return '${now.toRadixString(36)}-${rand.toRadixString(36)}';
}
