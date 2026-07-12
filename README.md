# EVS Remote — управление ПК в сети

Мобильное приложение (Flutter) к вашему домашнему парку машин: Wake-on-LAN,
мониторинг состояния через агент, голосовой ввод в EVS. Цель по платформам —
**Android 7.0+ (API 24)** и **iOS**.

В архиве лежит только то, что писалось вручную: весь `lib/`, `pubspec.yaml`,
тесты и готовые нативные конфиги. Платформенные папки `android/` и `ios/`
генерирует сам Flutter командой `flutter create` — так надёжнее, чем возить
их в архиве (Gradle-обёртка и Xcode-проект привязаны к версии SDK).

## Что нужно

- Flutter SDK 3.19+ (`flutter --version`)
- VS Code с расширениями **Flutter** и **Dart**
- Android: Android Studio или командные `cmdline-tools` + эмулятор/устройство
- iOS: только на macOS с Xcode

## Быстрый старт

```bash
# 1. Распакуйте архив и войдите в папку
cd evs_remote

# 2. Сгенерируйте платформенные папки вокруг существующего кода.
#    Замените com.yourname на свой домен в обратной записи.
flutter create --platforms=android,ios --org com.yourname .

# 3. Установите зависимости
flutter pub get
```

Команда `flutter create .` создаёт `android/` и `ios/`, но **перезапишет**
`lib/main.dart` шаблонным счётчиком. Восстановите наш `lib/` и `pubspec.yaml`
из архива поверх сгенерированных (просто скопируйте с заменой). После этого
`lib/main.dart` снова наш.

> Порядок надёжнее наоборот: сначала `flutter create` в пустой папке, затем
> скопировать в неё `lib/`, `pubspec.yaml`, `test/`, `analysis_options.yaml`
> из архива с заменой.

## Нативная настройка (обязательно)

Приложение ходит к агенту по **http** (LAN и Tailscale), а не https — обе
платформы по умолчанию это блокируют. Плюс нужен доступ к сети и локальной сети.

### Android — `minSdk 24` и разрешения

Откройте `android/app/build.gradle` (или `build.gradle.kts`) и задайте minSdk:

```groovy
// Groovy DSL
android {
    defaultConfig {
        minSdkVersion 24
    }
}
```
```kotlin
// Kotlin DSL (build.gradle.kts) — в новых версиях Flutter
android {
    defaultConfig {
        minSdk = 24
    }
}
```

Затем замените `android/app/src/main/AndroidManifest.xml` на готовый из
`native/android/AndroidManifest.xml`. В нём уже прописаны разрешение INTERNET,
`usesCleartextTraffic="true"`, RECORD_AUDIO для будущего голоса и
POST_NOTIFICATIONS для push-алертов.

### Android — Firebase (push-уведомления об алертах)

Push для Android идёт через self-hosted **ntfy** на вашем сервере, настроенный
на релей через ваш собственный бесплатный Firebase-проект (без этого шага
приложение соберётся и заработает как обычно — просто без push, алерты
по-прежнему видны в приложении на переднем плане):

1. Создайте проект в [Firebase Console](https://console.firebase.google.com),
   добавьте в него Android-приложение с `applicationId`, который вы указали в
   `flutter create --org ...` (`<org>.evs_remote`).
2. Скачайте `google-services.json` и положите его в `android/app/google-services.json`
   (после `flutter create`, так как `android/` не хранится в репозитории).
3. Подключите Gradle-плагин Google services — добавьте classpath/plugin в
   `android/build.gradle(.kts)` и `android/app/build.gradle(.kts)`. Точный
   синтаксис зависит от версии Flutter Gradle Plugin — см. текущую
   документацию [FlutterFire](https://firebase.flutter.dev) и
   [Firebase для Android](https://firebase.google.com/docs/android/setup).
4. На сервере настройте self-hosted ntfy на релей push через этот же
   Firebase-проект (ключи конфигурации ntfy меняются между версиями — см.
   актуальную документацию [ntfy self-hosting](https://docs.ntfy.sh/install/)).

### iOS — App Transport Security и локальная сеть

Откройте `ios/Runner/Info.plist` и добавьте внутрь корневого `<dict>` ключи из
`native/ios/Info-additions.plist` (ATS, доступ к локальной сети, микрофон).
Минимальную версию iOS при необходимости поднимите в Xcode (обычно 12/13
хватает).

## Запуск

```bash
flutter run              # на подключённом устройстве/эмуляторе
flutter test             # юнит-тесты (форматирование, валидация)
flutter build apk --release   # сборка APK
```

В VS Code: F5 или «Run and Debug». Выбор устройства — в правом нижнем углу.

## Сборка APK в облаке (GitHub Actions)

Если под рукой нет Android SDK, APK собирается в CI — workflow
`.github/workflows/build-apk.yml` (запуск вручную через вкладку **Actions →
Build APK → Run workflow**, либо автоматически при пуше кода в `main`). Готовый
`app-release.apk` кладётся в артефакты запуска (подписан debug-ключом —
устанавливается сайдлоадом).

Для Android папка `android/` **закоммичена и настроена** (в отличие от `ios/`,
которая по-прежнему генерируется `flutter create`): applicationId
`com.kekw2077.evs_remote`, `minSdk 24`, core library desugaring для
`flutter_local_notifications`, Gradle-плагин Google services для FCM.

Push (Firebase) требует `google-services.json` — он **не хранится в репозитории**
(в `.gitignore`), а подставляется в CI из секрета репозитория
`GOOGLE_SERVICES_JSON`. Подготовка:

1. Создайте бесплатный проект в [Firebase Console](https://console.firebase.google.com),
   добавьте Android-приложение с package name **`com.kekw2077.evs_remote`**,
   скачайте `google-services.json`.
2. Закодируйте в base64 и положите в секрет репозитория
   (**Settings → Secrets and variables → Actions → New repository secret**,
   имя `GOOGLE_SERVICES_JSON`):
   ```bash
   base64 -w0 google-services.json   # Linux; на macOS: base64 google-services.json
   ```
3. Запустите workflow. Без секрета сборка остановится с понятной ошибкой.

Локальная сборка APK на машине с Android SDK работает так же, но требует
положить `google-services.json` в `android/app/` вручную.

## Как это связано с агентом

Приложение ждёт на каждой отслеживаемой машине HTTP-агент:

```
GET  /health         -> 200 (без токена)          — доступность, определение загрузки
GET  /metrics        -> {cpu,ram,disk,...}         — Bearer-токен
GET  /alerts         -> {alerts:[{id,level,message}]} — пороги машины + проблемы Nextcloud, Bearer-токен
GET  /alert-config   -> {cpu,ram,disk,temperature,ntfyTopic} — текущие пороги/топик этого хоста, Bearer-токен
PUT  /alert-config    <- {cpu?,ram?,disk?,temperature?,ntfyTopic?} — задать пороги/топик, Bearer-токен
GET  /nextcloud      -> {configured,reachable,maintenance,version,...} — состояние Nextcloud, Bearer-токен
POST /wake           -> {mac,broadcast,port}       — ретрансляция magic-пакета
```

Это тот самый `agent slim.py` в корне репозитория. Токен из
`/etc/pc-agent.env` вводится в карточке компьютера (вкладка «Статус») и в
настройках ретранслятора. Пороги алертов и топик ntfy тоже настраиваются в
карточке компьютера — телефон источник истины, агент просто сохраняет и
исполняет присланное (`pc-agent-config.json` рядом с `agent slim.py`, путь
переопределяется через `PC_AGENT_STATE_FILE`).

### Push-уведомления об алертах (опционально)

Если на сервере задать `PC_AGENT_NTFY_URL` (адрес self-hosted ntfy) и в
приложении — топик ntfy для хоста (поле «Топик ntfy» в карточке компьютера),
агент раз в `PC_AGENT_WATCH_INTERVAL` секунд (по умолчанию 10) сам проверяет
алерты и публикует push при появлении нового — не переспрашивая приложение и
не завися от того, открыто ли оно. См. «Android — Firebase» выше для полной
брендированной интеграции push. **iOS**: без Apple Developer Program push в
самом приложении не работает — установите официальное приложение ntfy и
подпишитесь на `https://<ваш-ntfy-домен>/<topic>`; экран «Состояние» в
приложении по-прежнему показывает алерты как обычно, пока оно открыто.

### Мониторинг Nextcloud (опционально)

Если Nextcloud крутится на той же машине, что и агент, задайте на сервере
`PC_AGENT_NC_URL` (адрес облака, например `https://cloud.example.com`) — агент
раз в `PC_AGENT_NC_INTERVAL` секунд (по умолчанию 60) читает `/status.php`
(доступность, режим обслуживания, версия) и, если задан `PC_AGENT_NC_TOKEN`
(токен приложения **serverinfo**), подробную статистику через serverinfo API
(пользователи, активные за 5м/1ч/24ч, файлы, общие ресурсы, свободное место,
обновления приложений, версии PHP/БД/веб-сервера, размер БД). Отдельная вкладка
**«Облако»** показывает полный дашборд, а компактный блок — в карточке
компьютера. Проблемы (облако недоступно, режим обслуживания, требуется апгрейд
БД, обновления приложений/ядра, предупреждения настройки) добавляются в общий
поток алертов — то есть тоже попадают в push через ntfy. **Учётные данные
Nextcloud остаются на сервере** (в env-переменных агента), в телефон не передаются.

Токен serverinfo генерируется на сервере Nextcloud:
```
occ config:app:set serverinfo token --value "$(openssl rand -hex 32)"
```
(в Nextcloud AIO — через `docker exec ... occ ...`). Без токена работает только
`/status.php` — доступность, режим обслуживания и версия.

**Глубокие проверки (обновление ядра, предупреждения настройки/безопасности)**
требуют доступа агента к `occ` — задайте `PC_AGENT_NC_OCC` с префиксом вызова:
```
# Nextcloud AIO:
PC_AGENT_NC_OCC="docker exec --user www-data nextcloud-aio-nextcloud php occ"
# обычный Nextcloud:
PC_AGENT_NC_OCC="sudo -u www-data php /var/www/nextcloud/occ"
```
Агент вызовет `occ update:check` (обновление ядра) и `occ setupchecks`
(предупреждения). Для варианта с `docker exec` агенту нужен доступ к Docker
(состоять в группе `docker` или запускаться от root) — это фактически права
root, учитывайте при настройке. Без `PC_AGENT_NC_OCC` эти проверки просто не
запускаются.

### Два пути Wake-on-LAN

- **Прямой** — телефон сам шлёт magic-пакет по UDP. Работает, когда телефон
  в той же сети (дома по Wi-Fi).
- **Через ретранслятор** — телефон просит сервер (`POST /wake`) отправить
  пакет в LAN. Нужен из внешней сети, где широковещание не проходит. Настройки
  → «Ретранслятор Wake-on-LAN». Ретранслятор не обязательно через Tailscale —
  включите «HTTPS (публичный адрес)» и укажите домен/порт, за которым ваш
  сервер доступен напрямую (например через обратный прокси с TLS и проброс
  порта на роутере, если у вас статический IP).

Сам сервер разбудить из внешней сети нельзя, пока он спит — для него оставьте
приложение роутера, SSH к роутеру или Tailscale, если он уже настроен.

## Структура

```
lib/
  core/        токены темы, форматирование, валидация, генератор id
  models/      WolTarget, MonitoredHost, HostMetrics, AlertItem, AlertConfig, NextcloudStatus
  services/    prefs_store, agent_client (http), wol_sender (udp), push_service (FCM+local-notifications)
  state/       четыре ChangeNotifier-контроллера (provider)
  screens/     root_shell + пять вкладок (Голос, WoL, Статус, Облако, Настройки)
  widgets/     форма добавления, визуализатор голоса, поле ввода
native/        готовые AndroidManifest.xml и Info.plist-ключи
```

## Что уже реально, что пока условно

- **EVS** (`evs_controller.dart`) — открывает настоящий WebSocket
  (`ws://host:port/mobile`, пакет `web_socket_channel`). Формат сообщений
  (`{"type": "command"|"recognized", "text": ...}`) провизорный — финализируется
  вместе с функцией приёма на стороне десктопного EVS, которой пока нет.
- **Метрики и алерты** — реальный `fetch` для `/metrics`/`/alerts`, пороги и
  топик ntfy настраиваются per-host и реально пушатся на агент (`PUT /alert-config`).
- **Push-уведомления** (`push_service.dart`) — Android: Firebase + `flutter_local_notifications`,
  показывает алерт даже когда приложение свёрнуто/закрыто, тап открывает
  вкладку «Состояние». iOS: не реализовано в приложении (см. «Push-уведомления
  об алертах» выше) — осознанный компромисс ради экономии $99/год Apple
  Developer Program, а не недоработка.
- **Ретранслятор WoL** — доступен по HTTPS без Tailscale, если включить
  «HTTPS (публичный адрес)» в настройках и обеспечить внешнюю доступность
  сервера (обратный прокси + проброс порта).
- **Визуализатор голоса** (`waveform.dart`) — амплитуда это RMS из PCM16-потока
  микрофона (пакет `record`), не синтетика.
- **Ничего из push/алертов/HTTPS-ретранслятора не проверено на реальном
  устройстве** — машина разработки без Android SDK/Visual Studio, `agent slim.py`
  не запустить на Windows. Проверено только `flutter analyze`/`flutter test`/
  `python -m py_compile`.
