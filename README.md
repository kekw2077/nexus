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
`usesCleartextTraffic="true"` и RECORD_AUDIO для будущего голоса.

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

## Как это связано с агентом

Приложение ждёт на каждой отслеживаемой машине HTTP-агент:

```
GET  /health   -> 200 (без токена)          — доступность, определение загрузки
GET  /metrics  -> {cpu,ram,disk,...}         — Bearer-токен
GET  /alerts   -> {alerts:[{id,level,message}]} — превышенные пороги cpu/ram/disk/temperature, Bearer-токен
POST /wake     -> {mac,broadcast,port}       — ретрансляция magic-пакета
```

Это тот самый `agent_slim.py`, что мы собрали ранее. Токен из
`/etc/pc-agent.env` вводится в карточке компьютера (вкладка «Статус») и в
настройках ретранслятора.

### Два пути Wake-on-LAN

- **Прямой** — телефон сам шлёт magic-пакет по UDP. Работает, когда телефон
  в той же сети (дома по Wi-Fi).
- **Через ретранслятор** — телефон просит сервер (`POST /wake`) отправить
  пакет в LAN. Нужен из внешней сети, где широковещание не проходит. Настройки
  → «Ретранслятор Wake-on-LAN».

Сам сервер разбудить из внешней сети нельзя, пока он спит (нет Tailscale) —
для него оставьте приложение роутера или SSH к роутеру.

## Структура

```
lib/
  core/        токены темы, форматирование, валидация, генератор id
  models/      WolTarget, MonitoredHost, HostMetrics
  services/    prefs_store, agent_client (http), wol_sender (udp)
  state/       четыре ChangeNotifier-контроллера (provider)
  screens/     root_shell + четыре вкладки
  widgets/     форма добавления, визуализатор голоса, поле ввода
native/        готовые AndroidManifest.xml и Info.plist-ключи
```

## Что уже реально, что пока условно

- **EVS** (`evs_controller.dart`) — открывает настоящий WebSocket
  (`ws://host:port/mobile`, пакет `web_socket_channel`). Формат сообщений
  (`{"type": "command"|"recognized", "text": ...}`) провизорный — финализируется
  вместе с функцией приёма на стороне десктопного EVS, которой пока нет.
- **Метрики и алерты** — реальный `fetch` для `/metrics` и `/alerts`, работает
  сразу, как только запустите агент.
- **Визуализатор голоса** (`waveform.dart`) — амплитуда это RMS из PCM16-потока
  микрофона (пакет `record`), не синтетика.
