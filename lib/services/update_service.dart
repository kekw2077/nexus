import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Данные о доступном обновлении с GitHub Releases.
class UpdateInfo {
  UpdateInfo({
    required this.version,
    required this.notes,
    required this.pageUrl,
    this.apkUrl,
    this.apkSize = 0,
  });

  final String version; // без префикса «v», например 0.2.0
  final String notes; // тело релиза (markdown)
  final String pageUrl; // страница релиза на GitHub
  final String? apkUrl; // прямая ссылка на .apk-ассет (null — если его нет)
  final int apkSize; // размер APK в байтах

  bool get hasApk => apkUrl != null;
}

/// Проверка и загрузка обновлений через публичный GitHub Releases API.
/// Источник — репозиторий kekw2077/nexus. Токен не нужен (репозиторий публичный).
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _owner = 'kekw2077';
  static const _repo = 'nexus';
  static const releasesUrl = 'https://github.com/$_owner/$_repo/releases';

  /// Текущая версия приложения (versionName из сборки).
  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Возвращает [UpdateInfo], если последний релиз новее текущей версии.
  /// null — уже актуальная версия. Бросает исключение при сетевой ошибке.
  Future<UpdateInfo?> checkForUpdate() async {
    final current = await currentVersion();

    final res = await _client.get(
      Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) {
      throw Exception('GitHub ответил ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (body['tag_name'] as String? ?? '').replaceFirst(RegExp('^v'), '');
    if (tag.isEmpty || !isNewer(tag, current)) return null;

    String? apkUrl;
    int apkSize = 0;
    for (final asset in (body['assets'] as List? ?? const []).whereType<Map<String, dynamic>>()) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        apkUrl = asset['browser_download_url'] as String?;
        apkSize = (asset['size'] as num?)?.toInt() ?? 0;
        break;
      }
    }

    return UpdateInfo(
      version: tag,
      notes: (body['body'] as String? ?? '').trim(),
      pageUrl: body['html_url'] as String? ?? releasesUrl,
      apkUrl: apkUrl,
      apkSize: apkSize,
    );
  }

  /// Скачивает APK во временную папку, сообщая прогресс 0..1 (если известен размер).
  /// Возвращает путь к файлу. Установку запускает вызывающий код (OpenFilex).
  Future<String> downloadApk(String url, {void Function(double)? onProgress}) async {
    final resp = await _client.send(http.Request('GET', Uri.parse(url)));
    if (resp.statusCode != 200) {
      throw Exception('Ошибка загрузки: HTTP ${resp.statusCode}');
    }

    final total = resp.contentLength ?? 0;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/nexus-update.apk');
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink.close();
    }
    return file.path;
  }

  /// semver-сравнение: true, если [candidate] строго новее [current].
  /// Разбирает x.y.z, лишние части и суффиксы (-beta, +build) игнорирует.
  static bool isNewer(String candidate, String current) {
    final a = _parse(candidate);
    final b = _parse(current);
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  static List<int> _parse(String v) {
    final core = v.trim().replaceFirst(RegExp('^v'), '').split('+').first.split('-').first;
    final parts = core.split('.');
    return [for (var i = 0; i < 3; i++) i < parts.length ? int.tryParse(parts[i]) ?? 0 : 0];
  }

  void dispose() => _client.close();
}
