# EVS (Mirai) — контекст проекта

> Документ для передачи контекста между чатами. Прикладывай его в начало новой сессии, чтобы не объяснять проект заново.
> Последнее обновление: 2026-07-12.

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
- **Мониторинг Nextcloud (добавлено 2026-07-12):** агент (на том же сервере, что облако) опрашивает `status.php`+serverinfo, отдаёт `GET /nextcloud`, NC-алерты (`nc-unreachable`/`nc-maintenance`/`nc-db-upgrade`/`nc-update`) вливаются в `all_alerts()` → баннер + push. Клиент: `NextcloudStatus`, `AgentClient.nextcloud()`, `MonitorController.nextcloudFor`, `_NextcloudCard` (виден при `configured==true`). Учётные данные NC — только в env агента (`PC_AGENT_NC_URL`/`PC_AGENT_NC_TOKEN`/`PC_AGENT_NC_INTERVAL`). Не проверено на реальном облаке; структура serverinfo зависит от версии NC — сверить при деплое (SERVER_DEPLOY.md §4.5). Тест `test/nextcloud_status_test.dart`.
- **Runbook для сервера:** `SERVER_DEPLOY.md` в корне — самодостаточная инструкция для отдельного чата с SSH-доступом к серверу (агент systemd, ntfy, Caddy, проверка портов, мониторинг Nextcloud). Ещё не исполнена — сервер не разворачивался.
- **Сессия 2026-07-13 (облачный Claude Code, ветка `claude/file-instruction-review-2rhngz`, без Flutter SDK — только ручная вычитка + `py_compile`):**
  1. **iOS под AltStore** — CI `.github/workflows/build-ios.yml` на macOS-раннере: генерит `ios/` на лету, патчит Info.plist (ATS/локальная сеть/микрофон) + iOS 15, собирает **неподписанный `.ipa`**. iOS-иконка через `background_color_ios` (full-bleed под маску iOS). Ограничения free-подписи: нет push (APNs), переустановка раз в 7 дней.
  2. **WAN-WoL** — `WolSender` резолвит DDNS/хостнейм; **per-target флаг `directSend`** (тумблер «Напрямую, минуя ретранслятор» + бейдж «WAN» на карточке) — WAN-цель шлётся прямо, минуя релей. README: настройка роутера (статический ARP + проброс, CGNAT-оговорки).
  3. **Поиск машин в сети** — `network_scanner.dart` (скан /24 на `GET /health`) + `NetworkScanSheet` с кнопкой «Добавить» → предзаполнение формы мониторинга; агент `/health` отдаёт `hostname`. MAC из песочницы недоступен → находки в мониторинг, локальный IP (снаружи заменить на Tailscale-имя).
  4. **Мелочи формы** — редактируемое поле broadcast для мониторинга (было зашито 255.255.255.255); автоформат MAC (`MacInputFormatter`).
  - Тесты: `mac_formatter_test`, `network_scanner_test`, `wol_target_test`. Порт WoL: UDP 9, на приёме неважен (NIC ловит аппаратно).
- **Следующий шаг:** прогнать CI-сборки (`build-ios` — проверить Firebase-поды/iOS target; `build-apk` — нужен секрет `GOOGLE_SERVICES_JSON`); развернуть сервер по `SERVER_DEPLOY.md`; передеплой `agent slim.py` (для `hostname` в `/health`); собрать и проверить на реальном телефоне; далее — механизм обновления Nexus, переименование в nexus.
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
- `GET /nextcloud` → `{configured,reachable,maintenance,needsDbUpgrade,version,hasServerinfo,activeUsers,numUsers,numFiles,numShares,freeSpaceBytes,appUpdates,coreUpdateAvailable,coreUpdateVersion,warningsCount,warnings,phpVersion,webserver,database,dbSizeBytes}` — состояние Nextcloud, Bearer-токен; `configured:false` если облако у агента не настроено
- `POST /wake` → `{mac,broadcast,port}` — ретрансляция magic-пакета, HTTPS-доступен если ретранслятор выставлен через обратный прокси (см. «Два пути Wake-on-LAN»)

Фоновый watcher-поток (`_watch_loop`, `threading.Thread(daemon=True)`, запускается из `main()` только если задан `PC_AGENT_NTFY_URL`): раз в `PC_AGENT_WATCH_INTERVAL` сек (по умолчанию 10) пересчитывает алерты (`all_alerts()` = метрики машины + Nextcloud) и публикует push в self-hosted ntfy (`ntfyTopic` из конфига) только для **новых** алертов (edge-triggered по `_active_alert_ids`, не спамит, пока условие держится).

**Мониторинг Nextcloud** (агент на том же сервере, что облако): отдельный поток `_nc_loop` (запускается только при `PC_AGENT_NC_URL`) раз в `PC_AGENT_NC_INTERVAL` сек (по умолчанию 60) читает `/status.php` (без авторизации), при `PC_AGENT_NC_TOKEN` (токен serverinfo) — serverinfo API (пользователи/активные/файлы/ресурсы/место/обновления приложений + техинфа: PHP/БД+размер/веб-сервер), и при `PC_AGENT_NC_OCC` (префикс вызова occ, напр. `docker exec --user www-data nextcloud-aio-nextcloud php occ`) — `occ update:check` (обновление ядра) и `occ setupchecks --output=json` (предупреждения настройки/безопасности) через `_occ_checks()`/`_run_occ()` (`subprocess`+`shlex`). Всё кэшируется в `_nc_state` под `_nc_lock`. `compute_nc_alerts()` → `nc-unreachable`/`nc-maintenance`/`nc-db-upgrade`/`nc-update`/`nc-core-update`/`nc-warnings`, вливаются в `all_alerts()` → баннер + push. Место на диске/CPU/RAM сервера намеренно не дублируются (в обычных алертах машины). Учётные данные NC — только в env агента. **occ требует доступа агента к Docker (группа docker ≈ root); несовместимо с `DynamicUser=yes` — см. SERVER_DEPLOY.md §4.5.** Формат `occ setupchecks`/serverinfo зависит от версии NC — разбор защищённый, сверить при деплое.

Клиент: `AgentClient.alerts()`/`setAlertConfig()`/`nextcloud()` в `lib/services/agent_client.dart`, модели `lib/models/alert_item.dart`/`alert_config.dart`/`nextcloud_status.dart`, опрашивается вместе с `/metrics` в `MonitorController._pollOnce` (раз в 4 сек, только для онлайн-хостов; `alertsFor`/`nextcloudFor`). Отображение: (1) компактный `_NextcloudCard` в карточке хоста (`computer_status_screen.dart`, виден при `configured==true`) и (2) **отдельная вкладка «Облако»** (`cloud_status_screen.dart`, 5-я вкладка в `RootShell` после «Статус» — `statusTabIndex=2` не сдвинут) с полным дашбордом: статус-хедер, блок проблем, плитки использования, серверная техинфа, список предупреждений; заглушка если ни один агент не отдал `configured`. Push независимо от опроса приходит через `lib/services/push_service.dart` (Firebase+`flutter_local_notifications`, Android-only, тап → вкладка «Состояние» через `RootShell.selectedTab`).

**Два пути Wake-on-LAN:** прямой (телефон сам шлёт UDP magic-пакет в той же сети) и через ретранслятор (`POST /wake`). Ретранслятор доступен и без Tailscale — переключатель «HTTPS (публичный адрес)» в настройках плюс обратный прокси/проброс порта на сервере (у пользователя статический IP + домен для Nextcloud AIO, порт выберет сам).

### Структура `lib/`

- `core/` — токены темы, форматирование, валидация (+`validatePercent`/`validateTempThreshold`), генератор id
- `models/` — WolTarget, MonitoredHost (+пороги/ntfyTopic), HostMetrics, AlertItem, AlertConfig, NextcloudStatus
- `services/` — prefs_store, agent_client (http/https), wol_sender (udp), push_service (Firebase+local-notifications)
- `state/` — четыре ChangeNotifier-контроллера (provider)
- `screens/` — root_shell (+`selectedTab`/`statusTabIndex` для навигации по тапу на push) + пять вкладок (Голос, WoL, Статус, Облако, Настройки); `cloud_status_screen.dart` — дашборд Nextcloud
- `widgets/` — форма добавления (+пороги/ntfyTopic), визуализатор голоса, поле ввода

### Иконка приложения

Выбран концепт **Hub · Status** (исходник `nexus icon hub status.svg`, в репозитории).
- Тёмный контейнер `#111A2E → #080D1A`, акцент cyan→blue→violet (`#4EE3D2 · #4C7DF0 · #8B6CF0`)
- Знак: центральный узел-хаб + шесть машин, одна в алерте — янтарь `#FFB454` (кодирует мониторинг состояния)
- Мастер 1024×1024; растеризован в `assets/icon/icon.png` (full-bleed), `icon_background.png` и `icon_foreground.png` (safe-zone, scale 0.88 от центра)
- `flutter_launcher_icons` подключён в `pubspec.yaml` (android+ios, `min_sdk_android: 24`, `remove_alpha_ios: true`, `background_color_ios: "#0B1120"`) и прогнан — адаптивная иконка Android и iOS-иконка сгенерированы в `android/`/`ios/` (не в репозитории, см. ниже)
- **iOS-скругление (2026-07-13):** iOS сам накладывает маску-суперэллипс и запрещает прозрачность, поэтому «скруглять» PNG не надо — нужен full-bleed квадрат. `remove_alpha_ios` заливает прозрачные углы мастера цветом `background_color_ios`; радиус мастера (`rx=224`) ≈ маске iOS, так что заливка попадает в обрезаемую зону и не видна. Отдельный iOS-PNG не нужен.

### Что уже реально, что условно

- **EVS** (`evs_controller.dart`) — реальный WebSocket (`web_socket_channel`, `ws://host:port/mobile`, статусы connecting/connected/error/disconnected по факту handshake). Формат сообщений (`{"type": "command"|"recognized", "text": ...}`) — провизорный контракт, финализируется вместе с функцией приёма на десктопе (её пока нет).
- **Метрики и алерты** — реальный `fetch`, пороги per-host реально пушатся на агент.
- **Мониторинг Nextcloud** — реальный `fetch` `status.php`+serverinfo на стороне агента, NC-блок в карточке + NC-алерты в общем потоке/push. Не проверено на реальном облаке (нужен сервер с Nextcloud); разбор ответа serverinfo защищённый, но структура зависит от версии NC — сверить при деплое (см. SERVER_DEPLOY.md §4.5).
- **Push-уведомления** — Android полноценно (Firebase, брендировано под Nexus), iOS сознательно нет (см. README).
- **iOS-сборка (2026-07-13)** — CI `build-ios.yml` на macOS-раннере: генерит `ios/` на лету, патчит Info.plist (ATS/локальная сеть/микрофон) + минимум iOS 15, собирает **неподписанный `.ipa`** для AltStore/SideStore (переподпись Apple ID на устройстве, без Developer Program). Ограничения free-подписи: push недоступен (APNs), переустановка раз в 7 дней. Не проверено вживую.
- **Ретранслятор WoL** — доступен по HTTPS без Tailscale (нужна инфра на сервере).
- **WAN-WoL (2026-07-13)** — `WolSender` резолвит DDNS/хостнейм, так что цель WoL может быть публичным адресом + проброшенным на роутере портом (для пробуждения самого сервера). Поле адреса WoL переименовано, добавлена подсказка про проброс+статический ARP.
- **Поиск машин в сети (2026-07-13)** — `network_scanner.dart` сканирует /24-подсети телефона на отклик `GET /health`, `NetworkScanSheet` показывает находки с кнопкой «Добавить» (предзаполняет форму мониторинга). Агент `/health` теперь отдаёт `hostname`. MAC из песочницы не добыть → находки идут в мониторинг, не в WoL; локальный IP → для доступа снаружи заменить на Tailscale-имя.
- **Broadcast для мониторинга (2026-07-13)** — в форме мониторинга появилось редактируемое поле broadcast (было зашито `255.255.255.255`); пусто → глобальный broadcast.
- **Автоформат MAC (2026-07-13)** — `MacInputFormatter`: авто-двоеточия + верхний регистр при вводе.
- **Визуализатор голоса** (`waveform.dart`) — реальный RMS из PCM16-потока микрофона (пакет `record`), не синтетика.
- **Ничего из этого не проверено на реальном устройстве** — на машине разработки нет Android SDK и Visual Studio (см. «На чём остановились»); проверено только `flutter analyze`/`flutter test`/`python -m py_compile`.

> Статус репозитория: `main` активно развивается (WebSocket/RMS/алерты/push/Nextcloud/CI-APK), релизов нет. Текущая ветка разработки — `claude/file-instruction-review-2rhngz`.

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
- [x] Nexus: мониторинг состояния Nextcloud (статус + serverinfo + NC-алерты/push) — сделано 2026-07-12 (`GET /nextcloud`, `NextcloudStatus`, `_NextcloudCard`, `PC_AGENT_NC_*`)
- [x] Nexus: отдельная вкладка «Облако» + occ-проверки (обновление ядра, предупреждения) + серверная техинфа — сделано 2026-07-12 (`cloud_status_screen.dart`, `PC_AGENT_NC_OCC`)
- [x] Nexus: iOS-сборка под AltStore — сделано 2026-07-13 (CI `build-ios.yml`, неподписанный `.ipa`, iOS 15+, iOS-иконка через `background_color_ios`)
- [ ] Nexus: собрать APK и проверить иконку/WebSocket/RMS/алерты/push/HTTPS-релей/Nextcloud на реальном телефоне (эта машина без Android SDK — отложено пользователем)
- [ ] Nexus: проверить первый прогон iOS-сборки в Actions (Firebase-поды + iOS deployment target — возможны нюансы)
- [x] Nexus: WAN-WoL (DDNS + проброшенный порт), broadcast-поле для мониторинга, автоформат MAC, поиск машин в сети — сделано 2026-07-13
- [x] Nexus: per-target флаг «WAN/direct» — сделано 2026-07-13 (`WolTarget.directSend`, тумблер «Напрямую, минуя ретранслятор» в форме WoL, `wake()` минует релей при флаге, бейдж «WAN» на карточке). Снимает прежний нюанс приоритета релея.
- [ ] Nexus (по желанию): чтобы поиск сразу давал адрес «из любой точки», научить агент отдавать в `/health`/`/metrics` Tailscale-имя и подставлять его вместо LAN-IP
- [ ] Деплой на сервере по `SERVER_DEPLOY.md`: агент systemd, ntfy-контейнер, Caddy на свободном порту, DNS A-записи, Firebase-проект + `google-services.json`, токен serverinfo для Nextcloud, проверить конфликт портов с Nextcloud AIO
- [ ] Разделить «порог» и «включён ли этот тип алерта» — сейчас выключение алерта эмулируется завышением порога, отдельного чекбокса нет (не запрашивалось явно, но стоит уточнить у пользователя при следующей возможности)
- [ ] (добавляй сюда по ходу работы)

---

## Журнал изменений

> Одна строка на изменение: дата — что сделано / на чём остановились.

- 2026-07-11 — прочитан репозиторий Nexus, описан в документе; выбрана иконка Hub · Status. Дальше: адаптивная иконка Android + `flutter_launcher_icons`.
- 2026-07-11 (вечер) — собрана иконка (icon/icon_background/icon_foreground), подключён и прогнан `flutter_launcher_icons` (org `com.kekw2077`, minSdk 24); версия зафиксирована 1.0.0; исправлены баг компиляции в `HostMetrics` (const + `DateTime`) и падающий тест `formatBytes`; `flutter analyze`/`flutter test` чистые. Сборка APK на этой машине невозможна (нет Android SDK) — следующий шаг: собрать и проверить на телефоне.
- 2026-07-11 (ночь) — реальный WebSocket в `evs_controller.dart`, реальный RMS в `waveform.dart`, `GET /alerts` в `agent slim.py` + клиент/баннер. Проверено только статически.
- 2026-07-11 (ночь, 2) — по плану `parallel-sprouting-origami.md` реализованы M1 (per-host пороги алертов + топик ntfy, `PUT/GET /alert-config`), M2 (HTTPS для WoL-ретранслятора без Tailscale), M3 (push через self-hosted ntfy + watcher-поток в агенте + Firebase/FCM/`flutter_local_notifications` на Android, iOS сознательно без интеграции). Добавлены тесты `alert_config_test.dart`/`agent_client_test.dart`. `flutter analyze`/`flutter test`/`python -m py_compile` чистые на каждом шаге. Всё закоммичено (`4594c12`).
- 2026-07-12 — запушены 3 коммита сессии в origin (репозиторий переехал на `github.com/kekw2077/nexus`). Создан `SERVER_DEPLOY.md` — runbook для чата с SSH к серверу. Добавлен **мониторинг Nextcloud**: агент читает `status.php`+serverinfo (`PC_AGENT_NC_URL`/`PC_AGENT_NC_TOKEN`/`PC_AGENT_NC_INTERVAL`, поток `_nc_loop`, `GET /nextcloud`, NC-алерты в `all_alerts()` → push); клиент `NextcloudStatus`/`AgentClient.nextcloud()`/`nextcloudFor`/`_NextcloudCard`; тест `nextcloud_status_test.dart`. `analyze`/`test` (24 теста)/`py_compile` чистые. Не проверено на реальном облаке/сервере/телефоне. Закоммичено `2143a96`.
- 2026-07-12 (3) — **CI-сборка APK через GitHub Actions** (`.github/workflows/build-apk.yml`, ручной запуск/пуш в main → артефакт `app-release.apk`, debug-подпись). Для этого папка `android/` **закоммичена и настроена** (в отличие от `ios/` — та по-прежнему генерируется): Gradle-плагин Google services (FCM), core library desugaring для `flutter_local_notifications`, `minSdk 24`, наш манифест с `POST_NOTIFICATIONS`, иконки Hub·Status. `google-services.json` в `.gitignore`, подставляется в CI из секрета `GOOGLE_SERVICES_JSON` (base64). `PushService.init()` в `main.dart` обёрнут в try/catch — сбой/отсутствие Firebase не роняет запуск. **Требует от пользователя:** создать Firebase-проект (Android app `com.kekw2077.evs_remote`), скачать `google-services.json`, добавить секрет — потом workflow соберёт push-capable APK. Выбран вариант «полная сборка с push» (не превью без Firebase).
- 2026-07-12 (2) — **отдельная вкладка «Облако»** (`cloud_status_screen.dart`, 5-я в `RootShell`): полный дашборд Nextcloud. Агент расширен: серверная техинфа из serverinfo (PHP/БД+размер/веб-сервер) и occ-проверки (`PC_AGENT_NC_OCC` → `occ update:check` обновление ядра, `occ setupchecks` предупреждения) через `_occ_checks()`/`_run_occ()`; новые NC-алерты `nc-core-update`/`nc-warnings`. `NextcloudStatus` +9 полей, тест дополнен (26 тестов). `analyze`/`test`/`py_compile` чистые. occ требует доступа агента к docker (≈root, несовместимо с `DynamicUser`) — задокументировано в SERVER_DEPLOY.md §4.5. Не проверено вживую.
- 2026-07-11 (ночь) — реальный WebSocket в `evs_controller.dart` (`web_socket_channel`); реальный RMS из микрофона в `waveform.dart` (пакет `record`); добавлен `GET /alerts` в `agent slim.py` (пользователь принёс файл в корень репо) + клиент (`AlertItem`, `AgentClient.alerts`, `MonitorController.alertsFor`, баннер в `computer_status_screen.dart`). Всё проверено только `flutter analyze`/`flutter test` — реального устройства и Android SDK на этой машине нет, пользователь отложил сборку APK. Следующий шаг: собрать/проверить на телефоне, когда будет машина с SDK.
- 2026-07-13 (3) — **per-target флаг WAN/direct**: `WolTarget.directSend` (+JSON/copyWith), тумблер «Напрямую, минуя ретранслятор» в форме WoL (`withDirectToggle`), `WolController.wake()` минует релей при флаге, бейдж «WAN · напрямую» на карточке. Теперь LAN- и WAN-цели уживаются в одном списке при включённом релее. Тест `wol_target_test.dart`. README обновлён.
- 2026-07-13 (2) — **правки по запросу пользователя**: (1) WAN-WoL — `WolSender` резолвит DDNS, WoL-цель может быть публичным адресом + проброшенным портом (README: настройка роутера — статический ARP + проброс, оговорки CGNAT); (2) редактируемое поле **broadcast** в форме мониторинга (было зашито 255.255.255.255); (3) **автоформат MAC** (`MacInputFormatter`); (4) **поиск машин в сети** — `network_scanner.dart` (скан /24 на `GET /health`), `NetworkScanSheet` с кнопкой «Добавить» → предзаполнение формы; агент `/health` отдаёт `hostname`. Тесты `mac_formatter_test`/`network_scanner_test`. Не проверено на устройстве (нет Flutter SDK в этой сессии) — только ручная вычитка + `py_compile` агента. Открытый нюанс: при включённом релее WAN-цель уйдёт через релей (не сработает) — задокументировано в TODO.
- 2026-07-13 — **iOS-адаптация под AltStore**: новый CI `.github/workflows/build-ios.yml` (macOS-раннер → `flutter create ios` на лету → патч Info.plist из `native/ios/Info-additions.plist` + iOS 15 min → `flutter build ios --no-codesign` → неподписанный `nexus-unsigned.ipa` в артефактах). Иконка под iOS: `background_color_ios: "#0B1120"` в `pubspec.yaml` (full-bleed под маску iOS, без пред-скругления). README: раздел «Сборка IPA в облаке», ограничения free-подписи (нет push/APNs, переустановка раз в 7 дней). Работа в этой сессии велась в облачном окружении Claude Code без Flutter SDK — сборка проверяется только запуском workflow в Actions. Обсуждается далее: правки формы добавления мониторинга + полей адреса, опция WoL из интернета через роутер. Ответ по порту WoL: UDP 9 (стандарт), на приёме порт неважен — magic-пакет ловит NIC на аппаратном уровне.
