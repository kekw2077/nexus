# EVS (Mirai) — контекст проекта

> Документ для передачи контекста между чатами. Прикладывай его в начало новой сессии, чтобы не объяснять проект заново.
> Последнее обновление: 2026-07-11 (ночь, 2).

---

## ⚙️ Как вести этот документ (правило)

**После каждого патча или правки кода — сразу обновляй этот файл.** Цель: не перебирать весь проект заново в новой сессии, а стартовать с того, на чём остановились.

Что обновлять после изменений:
1. Соответствующий раздел проекта (архитектура, эндпоинты, структура, заглушки).
2. Секцию **«На чём остановились»** ниже — текущее состояние и следующий шаг.
3. **Журнал изменений** внизу — одна строка: дата + что сделано.
4. Дату в шапке.
5. **Синхронизация с репозиторием** — после любого патча закоммитить изменения (и запушить, если есть договорённость с пользователем на конкретный пуш) в репозиторий `nexus`, чтобы рабочая копия и git всегда были в согласованном состоянии.

Заглушки/TODO помечай прямо в разделах и дублируй в «Открытые вопросы / TODO».

---

## 📍 На чём остановились

> Обновляй эту секцию в конце каждой сессии.

- **Текущее состояние:** реализованы три крупные фичи по плану (M1→M2→M3, файл плана: `parallel-sprouting-origami.md`, уже неактуален как файл — план исполнен):
  1. **M1 — per-host алерты**: пороги (`cpu/ram/disk/temperature`) и топик ntfy теперь настраиваются в карточке компьютера (`ComputerFormSheet`), пушатся на агент через `PUT /alert-config`, телефон — источник истины. `agent slim.py`: мутабельный `_config` под `threading.Lock`, персистентность в `pc-agent-config.json` (`PC_AGENT_STATE_FILE`), `GET/PUT /alert-config`. Dart: `AlertConfig` (новая модель), `MonitoredHost` +5 полей, `MonitorController.setAlertConfig`, валидаторы `validatePercent`/`validateTempThreshold`.
  2. **M2 — WoL без Tailscale**: `RelayConfig.secure` + переключатель «HTTPS (публичный адрес)» в настройках; `AgentClient._uri`/`wake()` умеют `https`. Реальная доступность (Caddy/DNS/проброс порта) — вне кода, пользователь настроит сам на своём Ubuntu-сервере (статический IP + существующий домен для Nextcloud AIO — свои A-записи, порт выберет сам, чтобы не пересечься с Nextcloud AIO).
  3. **M3 — push-уведомления**: watcher-поток в `agent slim.py` (`PC_AGENT_NTFY_URL`, `PC_AGENT_WATCH_INTERVAL`) — раз в N сек пересчитывает алерты, шлёт push в self-hosted ntfy только на **новые** (edge-triggered, не спамит). Flutter: `push_service.dart` — Firebase (`firebase_core`/`firebase_messaging`) + `flutter_local_notifications`, **Android-only** (обёрнуто в `if (!Platform.isIOS)`), канал `nexus_alerts` (Importance.high, NotificationVisibility.public — виден на заблокированном экране), тап открывает вкладку «Состояние» через `RootShell.selectedTab` (ValueNotifier, т.к. у PushService нет BuildContext). iOS — сознательно без интеграции (нет Apple Developer Program, $99/год), там официальное приложение ntfy.
  - По пути: `native/android/AndroidManifest.xml` + `POST_NOTIFICATIONS`; README расписывает Firebase-проект/`google-services.json`/Gradle-плагин (точный синтаксис — сверить с текущей документацией FlutterFire, не фиксировано намеренно) и self-hosted ntfy (ключи конфигурации ntfy для Firebase-релея — тоже сверить на месте, версии меняются).
  - Тесты: `test/alert_config_test.dart` (round-trip), `test/agent_client_test.dart` (схема http/https в `wake()` через фейковый `http.Client`). `flutter analyze`/`flutter test` чистые на каждом шаге, `python -m py_compile "agent slim.py"` — тоже.
- **Важное ограничение окружения:** на машине, где идёт разработка (Windows), **нет Android SDK и Visual Studio** — здесь нельзя собрать APK, запустить на Windows-десктопе или проверить что-либо из M1/M2/M3 на реальном устройстве/сервере. Всё выше проверено только статически. `agent slim.py` — Linux/Ubuntu-only (`/proc`, `os.statvfs`, `os.getloadavg`), на Windows только `py_compile`.
- **Не сделано / уточнить на сервере при деплое (не блокирует код):** точные ключи self-hosting ntfy под свой Firebase-проект; не занимает ли Nextcloud AIO порты 80/443 (новым сервисам — свои порты/TLS, не трогать её прокси без проверки); путь для `pc-agent-config.json` под правами systemd-юзера.
- **Следующий шаг:** развернуть на сервере (Caddy/DNS/порты, ntfy-контейнер, Firebase-проект, `google-services.json` в `android/app/`), собрать APK на машине с Android SDK и проверить вживую на телефоне (WebSocket к десктопному EVS всё ещё некому принимать — там тоже нужна серверная часть); далее — механизм обновления Nexus, переименование в nexus.
- **Открытые вопросы:** финализировать переименование `evs_remote` → `nexus`; определить механизм обновления Nexus; протокол сообщений EVS WebSocket — провизорный, зависит от десктопной реализации; ntfy-топик — один на хост (решено), но нет UI для "какие типы алертов включены" отдельно от порогов (порог можно эффективно выключить, оставив его 100/150 — отдельного чекбокса нет, не запрашивалось явно).

---

## Что это

**EVS (Enhanced Voice System)**, в репозитории — **Mirai**. Русскоязычный десктопный голосовой ассистент.

- **Платформа:** Windows 11
- **Фронтенд:** Flutter
- **Бэкенд:** Python-сайдкар
- **Связь фронт ↔ бэк:** WebSocket

---

## Стек и интеграции

- **STT:** faster-whisper (основной), прототипы на **Silero VAD** + **GigaAM-v3** через **sherpa-onnx** как более быстрая альтернатива
- **VAD:** webrtcvad, Silero VAD
- **Шумоподавление:** RNNoise / DeepFilterNet (в планах, см. ТЗ)
- **TTS:** Piper (русские голоса), также pyttsx3
- **LLM:** Ollama (локальный инференс)

---

## Архитектура STT/аудио (текущий фокус)

- Абстракция STT-движка с **горячим переключением** (hot-switching) между движками
- Пайплайн шумоподавления (RNNoise/DeepFilterNet)
- Выбор микрофона с хранением denoise-настроек **по каждому устройству**
- Выбор устройства **CPU/GPU по каждому компоненту** отдельно
- Единый **GPU-offload**: детекция полноэкранного режима + мониторинг VRAM
- Оптимизация холодного старта через **стейт-машину запуска**

## Flutter UI

- Виджеты визуализации звука: bar visualizer, Siri orb, particle sphere, варианты wave field
- Унификация тем
- Персистентность позиций окон и виджетов (фиксы)
- UX сохранения/отмены настроек (save/cancel)

## Прочие модули (по ТЗ)

- Менеджер моделей: скачивание + проверка целостности
- Выбор голосов Piper TTS
- Разделы настроек (см. ниже)

---

## Экраны настроек (RU, 7 разделов)

1. Общие
2. Голосовой ввод
3. Команды
4. Модель / инференс
5. Личность / память
6. Приватность
7. О программе

> Проектировались через HTML-макеты с рендером в PNG.

---

## Механизм обновлений приложения

Встроенный апдейтер с ручной проверкой:

1. В приложении есть кнопка **«Проверить обновления»**
2. При наличии обновления оно **скачивается**
3. После скачивания предлагается **перезагрузка**, и обновление **устанавливается при перезапуске**

> Уточнить при случае:
> - Отдельно ли обновляется Python-сайдкар и модели (STT/TTS/LLM), или всё идёт одним билдом?
> - Источник обновлений (свой сервер / GitHub Releases / другое) и версионирование/канал релизов.

---

## Nexus — мобильный компаньон (репозиторий `nexus`, папка/приложение `evs_remote`)

Мобильное Flutter-приложение к домашнему парку машин. Рабочее имя — **Nexus** (в README пока «EVS Remote — управление ПК в сети»).

- **Репозиторий:** https://github.com/kekw2077/nexus (публичный)
- **Назначение:** управление ПК в локальной сети (Wake-on-LAN), мониторинг состояния через агент, голосовой ввод в EVS; цель — приём алертов о проблемах с сервера
- **Платформы:** Android 7.0+ (API 24) и iOS
- **Язык:** Dart 100%, стейт — provider (ChangeNotifier)

**Что лежит в репозитории:** только рукописный код — `lib/`, `pubspec.yaml`, `test/`, `analysis_options.yaml`, готовые нативные конфиги в `native/`. Папки `android/` и `ios/` генерируются через `flutter create` (не хранятся в репе).

### Требования и старт

- Flutter SDK 3.19+, VS Code с расширениями Flutter и Dart
- Android: Android Studio / cmdline-tools; iOS: только macOS + Xcode
- Порядок: `flutter create` в пустой папке → скопировать поверх `lib/`, `pubspec.yaml`, `test/`, `analysis_options.yaml` с заменой → `flutter pub get`
- Сборка: `flutter run`, `flutter test`, `flutter build apk --release`

### Нативная настройка (обязательно)

Приложение ходит к агенту по **HTTP** (LAN и Tailscale), не https — обе платформы это по умолчанию блокируют.
- **Android:** `minSdk 24`; заменить `AndroidManifest.xml` на `native/android/AndroidManifest.xml` (INTERNET, `usesCleartextTraffic="true"`, RECORD_AUDIO, POST_NOTIFICATIONS)
- **iOS:** добавить в `Info.plist` ключи из `native/ios/Info-additions.plist` (ATS, доступ к локальной сети, микрофон)
- **Android push (опционально):** свой Firebase-проект + `google-services.json` в `android/app/` + Gradle-плагин Google services — см. README, раздел «Android — Firebase»

### Агент (`agent slim.py`, в корне репозитория)

HTTP-агент на каждой отслеживаемой машине (Linux/Ubuntu-only: `/proc`, `os.statvfs`, `os.getloadavg` — на этой Windows-машине не запустить, только `py_compile`-проверка синтаксиса). Токен — из `/etc/pc-agent.env` или `PC_AGENT_TOKEN`, вводится в карточке компьютера и в настройках ретранслятора.
- `GET /health` → 200, без токена — доступность / определение загрузки
- `GET /metrics` → `{cpu,ram,disk,...}`, Bearer-токен
- `GET /alerts` → `{alerts:[{id,level,message}]}`, Bearer-токен — пороги из мутабельного `_config` (не констант), считаются заново на каждый запрос без сохранения истории
- `GET/PUT /alert-config` → `{cpu,ram,disk,temperature,ntfyTopic}` — пороги/топик, телефон источник истины, персистентность в `pc-agent-config.json` (`PC_AGENT_STATE_FILE`), `PC_AGENT_ALERT_*` env — только seed-дефолты на первый запуск
- `POST /wake` → `{mac,broadcast,port}` — ретрансляция magic-пакета, HTTPS-доступен если ретранслятор выставлен через обратный прокси (см. «Два пути Wake-on-LAN»)

Фоновый watcher-поток (`_watch_loop`, `threading.Thread(daemon=True)`, запускается из `main()` только если задан `PC_AGENT_NTFY_URL`): раз в `PC_AGENT_WATCH_INTERVAL` сек (по умолчанию 10) пересчитывает алерты и публикует push в self-hosted ntfy (`ntfyTopic` из конфига) только для **новых** алертов (edge-triggered по `_active_alert_ids`, не спамит, пока условие держится).

Клиент: `AgentClient.alerts()`/`setAlertConfig()` в `lib/services/agent_client.dart`, модели `lib/models/alert_item.dart`/`alert_config.dart`, опрашивается вместе с `/metrics` в `MonitorController._pollOnce` (раз в 4 сек, только для онлайн-хостов), отображается баннером в `computer_status_screen.dart` (`_AlertsBanner`). Push независимо от опроса приходит через `lib/services/push_service.dart` (Firebase+`flutter_local_notifications`, Android-only, тап → вкладка «Состояние» через `RootShell.selectedTab`).

**Два пути Wake-on-LAN:** прямой (телефон сам шлёт UDP magic-пакет в той же сети) и через ретранслятор (`POST /wake`). Ретранслятор доступен и без Tailscale — переключатель «HTTPS (публичный адрес)» в настройках плюс обратный прокси/проброс порта на сервере (у пользователя статический IP + домен для Nextcloud AIO, порт выберет сам).

### Структура `lib/`

- `core/` — токены темы, форматирование, валидация (+`validatePercent`/`validateTempThreshold`), генератор id
- `models/` — WolTarget, MonitoredHost (+пороги/ntfyTopic), HostMetrics, AlertItem, AlertConfig
- `services/` — prefs_store, agent_client (http/https), wol_sender (udp), push_service (Firebase+local-notifications)
- `state/` — четыре ChangeNotifier-контроллера (provider)
- `screens/` — root_shell (+`selectedTab`/`statusTabIndex` для навигации по тапу на push) + четыре вкладки
- `widgets/` — форма добавления (+пороги/ntfyTopic), визуализатор голоса, поле ввода

### Иконка приложения

Выбран концепт **Hub · Status** (исходник `nexus icon hub status.svg`, в репозитории).
- Тёмный контейнер `#111A2E → #080D1A`, акцент cyan→blue→violet (`#4EE3D2 · #4C7DF0 · #8B6CF0`)
- Знак: центральный узел-хаб + шесть машин, одна в алерте — янтарь `#FFB454` (кодирует мониторинг состояния)
- Мастер 1024×1024; растеризован в `assets/icon/icon.png` (full-bleed), `icon_background.png` и `icon_foreground.png` (safe-zone, scale 0.88 от центра)
- `flutter_launcher_icons` подключён в `pubspec.yaml` (android+ios, `min_sdk_android: 24`, `remove_alpha_ios: true`) и прогнан — адаптивная иконка Android и iOS-иконка сгенерированы в `android/`/`ios/` (не в репозитории, см. ниже)

### Что уже реально, что условно

- **EVS** (`evs_controller.dart`) — реальный WebSocket (`web_socket_channel`, `ws://host:port/mobile`, статусы connecting/connected/error/disconnected по факту handshake). Формат сообщений (`{"type": "command"|"recognized", "text": ...}`) — провизорный контракт, финализируется вместе с функцией приёма на десктопе (её пока нет).
- **Метрики и алерты** — реальный `fetch`, пороги per-host реально пушатся на агент.
- **Push-уведомления** — Android полноценно (Firebase, брендировано под Nexus), iOS сознательно нет (см. README).
- **Ретранслятор WoL** — доступен по HTTPS без Tailscale (нужна инфра на сервере).
- **Визуализатор голоса** (`waveform.dart`) — реальный RMS из PCM16-потока микрофона (пакет `record`), не синтетика.
- **Ничего из этого не проверено на реальном устройстве** — на машине разработки нет Android SDK и Visual Studio (см. «На чём остановились»); проверено только `flutter analyze`/`flutter test`/`python -m py_compile`.

> Статус репозитория: 3 коммита (после текущего), релизов нет.

---

## Инфраструктура и окружение

- Основной ПК: Windows 11, два монитора (один 165 Гц), RTX 3060 12GB
- Домашний сервер: Ubuntu, крупный Docker-стек (~32 контейнера) — Nextcloud AIO, медиа-стек, Home Assistant с голосом, Ollama
- Доступ: Tailscale
- **Claude Desktop + SSH MCP-сервер** для диагностики сервера напрямую через Tailscale
- Для сервисов, требующих обхода блокировок, используется VPN (Windscribe — Psiphon ломал OAuth localhost-callback в Claude Code)

---

## История (кратко)

- **AURA** (Python/PyQt6) — предшественник EVS. VAD для снижения нагрузки CPU, фиксы QTimer-тредов, аудиовизуализатор, окно настроек на 10 вкладок, PEP8-рефактор.
- **EVS / Mirai** — текущий проект, пришёл на смену AURA.
- Смежные Flutter-проекты: «Alice AI» (чат), ранний Mirai с экранами памяти и ролеплея (тёмная тема).

---

## Открытые вопросы / TODO

- [ ] **Nexus: механизм обновления** — реализовать обновление внутри приложения (проверка версии → скачивание → установка) либо повторное скачивание APK; определить источник (GitHub Releases / свой сервер) и версионирование
- [ ] Финализировать переименование `evs_remote` → `nexus` (README, `cd evs_remote` в быстром старте, `name:` в `pubspec.yaml`)
- [x] Nexus: подцепить реальный WebSocket в `evs_controller.dart` — сделано 2026-07-11 (протокол сообщений провизорный, десктопной стороны приёма ещё нет)
- [x] Nexus: эндпоинт/поток под алерты о проблемах с сервера — сделано 2026-07-11 (`GET /alerts` в `agent slim.py` + клиент)
- [x] Nexus: заменить синтетику в `waveform.dart` на RMS с микрофона — сделано 2026-07-11
- [x] Nexus: собрать иконку Hub · Status под адаптивную схему Android + `flutter_launcher_icons` — сделано 2026-07-11
- [x] Nexus: per-host настройка порогов алертов (какие показывать + чувствительность), синхронизация с агентом — сделано 2026-07-11 (M1: `PUT/GET /alert-config`, `AlertConfig`, `ComputerFormSheet`)
- [x] Nexus: WoL-ретранслятор без Tailscale — сделано 2026-07-11 (M2: `RelayConfig.secure`, HTTPS в `AgentClient`; инфра — Caddy/DNS/порт на сервере, вне кода)
- [x] Nexus: push-уведомления об алертах (заблокированный экран + обычные) — сделано 2026-07-11 (M3: watcher в `agent slim.py` → self-hosted ntfy → Firebase → `push_service.dart`, Android-only)
- [ ] Nexus: собрать APK и проверить иконку/WebSocket/RMS/алерты/push/HTTPS-релей на реальном телефоне (эта машина без Android SDK — отложено пользователем)
- [ ] Деплой на сервере: ntfy-контейнер, Caddy (или альтернатива) на свободном порту, DNS A-записи в существующий домен, Firebase-проект + `google-services.json`, проверить конфликт портов с Nextcloud AIO
- [ ] Разделить «порог» и «включён ли этот тип алерта» — сейчас выключение алерта эмулируется завышением порога, отдельного чекбокса нет (не запрашивалось явно, но стоит уточнить у пользователя при следующей возможности)
- [ ] (добавляй сюда по ходу работы)

---

## Журнал изменений

> Одна строка на изменение: дата — что сделано / на чём остановились.

- 2026-07-11 — прочитан репозиторий Nexus, описан в документе; выбрана иконка Hub · Status. Дальше: адаптивная иконка Android + `flutter_launcher_icons`.
- 2026-07-11 (вечер) — собрана иконка (icon/icon_background/icon_foreground), подключён и прогнан `flutter_launcher_icons` (org `com.kekw2077`, minSdk 24); версия зафиксирована 1.0.0; исправлены баг компиляции в `HostMetrics` (const + `DateTime`) и падающий тест `formatBytes`; `flutter analyze`/`flutter test` чистые. Сборка APK на этой машине невозможна (нет Android SDK) — следующий шаг: собрать и проверить на телефоне.
- 2026-07-11 (ночь) — реальный WebSocket в `evs_controller.dart`, реальный RMS в `waveform.dart`, `GET /alerts` в `agent slim.py` + клиент/баннер. Проверено только статически.
- 2026-07-11 (ночь, 2) — по плану `parallel-sprouting-origami.md` реализованы M1 (per-host пороги алертов + топик ntfy, `PUT/GET /alert-config`), M2 (HTTPS для WoL-ретранслятора без Tailscale), M3 (push через self-hosted ntfy + watcher-поток в агенте + Firebase/FCM/`flutter_local_notifications` на Android, iOS сознательно без интеграции). Добавлены тесты `alert_config_test.dart`/`agent_client_test.dart`. `flutter analyze`/`flutter test`/`python -m py_compile` чистые на каждом шаге. Деплой на сервере (ntfy, Caddy, DNS, Firebase-проект) и проверка на реальном телефоне — не сделаны, машина разработки без Android SDK.
- 2026-07-11 (ночь) — реальный WebSocket в `evs_controller.dart` (`web_socket_channel`); реальный RMS из микрофона в `waveform.dart` (пакет `record`); добавлен `GET /alerts` в `agent slim.py` (пользователь принёс файл в корень репо) + клиент (`AlertItem`, `AgentClient.alerts`, `MonitorController.alertsFor`, баннер в `computer_status_screen.dart`). Всё проверено только `flutter analyze`/`flutter test` — реального устройства и Android SDK на этой машине нет, пользователь отложил сборку APK. Следующий шаг: собрать/проверить на телефоне, когда будет машина с SDK.
