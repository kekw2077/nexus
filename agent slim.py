#!/usr/bin/env python3
"""
PC Agent — метрики Ubuntu + ретранслятор Wake-on-LAN.
Только стандартная библиотека. Ни pip, ни venv не нужны.

    GET  /health          без токена, "жив ли хост"
    GET  /metrics         cpu / ram / disk / temperature / uptimeSec
    GET  /alerts          проблемы хоста (машина + Nextcloud) — пороги превышены
    GET  /alert-config    текущие пороги + топик ntfy для этого хоста
    PUT  /alert-config    задать пороги/топик с телефона — источник истины телефон
    GET  /nextcloud       состояние Nextcloud (status.php + serverinfo), если настроен
    POST /wake            {"mac": "00:1A:2B:3C:4D:5E", "broadcast": "192.168.1.255"}

Запуск:
    PC_AGENT_TOKEN=... python3 agent.py

Push-уведомления об алертах (опционально): задайте PC_AGENT_NTFY_URL
(адрес self-hosted ntfy, например https://ntfy.example.com) — тогда фоновый
поток раз в PC_AGENT_WATCH_INTERVAL секунд (по умолчанию 10) проверяет
алерты и публикует push в топик, заданный через PUT /alert-config
(поле ntfyTopic). Без PC_AGENT_NTFY_URL или ntfyTopic поток не запускается.

Мониторинг Nextcloud (опционально): задайте PC_AGENT_NC_URL (адрес облака,
например https://cloud.example.com) — фоновый поток раз в PC_AGENT_NC_INTERVAL
секунд (по умолчанию 60) читает /status.php (без авторизации) и, если задан
PC_AGENT_NC_TOKEN (токен приложения serverinfo), подробную статистику через
serverinfo API. Если задан PC_AGENT_NC_OCC (префикс вызова occ, например
"docker exec --user www-data nextcloud-aio-nextcloud php occ"), дополнительно
проверяются обновление ядра (occ update:check) и предупреждения настройки/
безопасности (occ setupchecks). Состояние отдаётся в /nextcloud, а проблемы
(недоступно, режим обслуживания, нужен апгрейд БД, обновления приложений/ядра,
предупреждения) добавляются в /alerts и пушатся тем же watcher'ом. Учётные
данные Nextcloud остаются на сервере, в телефон не передаются.
"""

from __future__ import annotations

import json
import os
import re
import secrets
import shlex
import socket
import struct
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

TOKEN = os.environ.get("PC_AGENT_TOKEN", "")
HOST = os.environ.get("PC_AGENT_HOST", "0.0.0.0")
PORT = int(os.environ.get("PC_AGENT_PORT", "8765"))
DISK_PATH = os.environ.get("PC_AGENT_DISK", "/")
WAKE_ENABLED = os.environ.get("PC_AGENT_WAKE", "1") == "1"

ALERT_CPU = int(os.environ.get("PC_AGENT_ALERT_CPU", "90"))
ALERT_RAM = int(os.environ.get("PC_AGENT_ALERT_RAM", "90"))
ALERT_DISK = int(os.environ.get("PC_AGENT_ALERT_DISK", "90"))
ALERT_TEMP = float(os.environ.get("PC_AGENT_ALERT_TEMP", "85"))

STATE_PATH = Path(os.environ.get("PC_AGENT_STATE_FILE", "pc-agent-config.json"))

NC_URL = os.environ.get("PC_AGENT_NC_URL", "").rstrip("/")
NC_TOKEN = os.environ.get("PC_AGENT_NC_TOKEN", "")
NC_INTERVAL = int(os.environ.get("PC_AGENT_NC_INTERVAL", "60"))
# Префикс вызова occ, если агент может достучаться до Nextcloud CLI. Например:
#   Nextcloud AIO: "docker exec --user www-data nextcloud-aio-nextcloud php occ"
#   обычный NC:    "sudo -u www-data php /var/www/nextcloud/occ"
# Пусто — occ-проверки (обновление ядра, предупреждения настройки) не запускаются.
NC_OCC = os.environ.get("PC_AGENT_NC_OCC", "")

if not TOKEN:
    raise SystemExit(
        "PC_AGENT_TOKEN не задан. Сгенерируйте:\n"
        f"  export PC_AGENT_TOKEN={secrets.token_urlsafe(24)}"
    )

MAC_RE = re.compile(r"^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$")


# --------------------------------------------------------------------------
# Настраиваемые с телефона пороги + топик ntfy. Телефон — источник истины:
# /alert-config только принимает и сохраняет то, что ему прислали; env-переменные
# ALERT_* — лишь seed-значения на первый запуск, если сохранённого файла ещё нет.
# --------------------------------------------------------------------------

_cfg_lock = threading.Lock()
_config: dict[str, float | str | None] = {
    "cpu": ALERT_CPU,
    "ram": ALERT_RAM,
    "disk": ALERT_DISK,
    "temperature": ALERT_TEMP,
    "ntfyTopic": None,
}

try:
    _loaded = json.loads(STATE_PATH.read_text())
    if isinstance(_loaded, dict):
        _config.update({k: v for k, v in _loaded.items() if k in _config})
except (FileNotFoundError, json.JSONDecodeError, OSError):
    pass


def get_config() -> dict[str, float | str | None]:
    with _cfg_lock:
        return dict(_config)


def set_config(patch: dict[str, float | str | None]) -> dict[str, float | str | None]:
    with _cfg_lock:
        _config.update({k: v for k, v in patch.items() if k in _config})
        snapshot = dict(_config)
        try:
            STATE_PATH.write_text(json.dumps(snapshot))
        except OSError:
            pass  # диск недоступен на запись — конфиг остаётся хотя бы в памяти
    return snapshot


# --------------------------------------------------------------------------
# Метрики: читаем /proc напрямую
# --------------------------------------------------------------------------

class CpuSampler:
    """
    /proc/stat отдаёт счётчики с момента загрузки, а не проценты.
    Занятость — это дельта между двумя чтениями, поэтому храним предыдущее.
    """

    def __init__(self) -> None:
        self._prev = self._read()

    @staticmethod
    def _read() -> tuple[int, int]:
        with open("/proc/stat") as f:
            parts = [int(x) for x in f.readline().split()[1:]]
        idle = parts[3] + parts[4]  # idle + iowait
        return sum(parts), idle

    def percent(self) -> int:
        total, idle = self._read()
        prev_total, prev_idle = self._prev
        d_total = total - prev_total
        d_idle = idle - prev_idle
        self._prev = (total, idle)
        if d_total <= 0:
            return 0
        return round(100 * (1 - d_idle / d_total))


def read_memory() -> tuple[int, int]:
    """Возвращает (процент занятого, всего байт). MemAvailable честнее, чем MemFree."""
    values: dict[str, int] = {}
    with open("/proc/meminfo") as f:
        for line in f:
            key, _, rest = line.partition(":")
            if key in ("MemTotal", "MemAvailable"):
                values[key] = int(rest.split()[0]) * 1024
            if len(values) == 2:
                break
    total = values["MemTotal"]
    available = values["MemAvailable"]
    return round(100 * (1 - available / total)), total


def read_disk(path: str) -> tuple[int, int]:
    st = os.statvfs(path)
    total = st.f_blocks * st.f_frsize
    free_for_root = st.f_bfree * st.f_frsize
    free_for_user = st.f_bavail * st.f_frsize
    used = total - free_for_root
    # Так же считает df: резерв под root не входит в знаменатель
    denominator = used + free_for_user
    percent = round(100 * used / denominator) if denominator else 0
    return percent, total


def read_uptime() -> int:
    with open("/proc/uptime") as f:
        return int(float(f.readline().split()[0]))


def read_temperature() -> float | None:
    """
    Ищем hwmon-чип процессора. На Zen 4 (R5 7500F, R9 5900X) это k10temp,
    нужная метка — Tctl. На Intel — coretemp / Package id 0.
    """
    wanted_chips = ("k10temp", "coretemp", "zenpower", "cpu_thermal")
    wanted_labels = ("Tctl", "Tdie", "Package id 0")

    for hwmon in sorted(Path("/sys/class/hwmon").glob("hwmon*")):
        try:
            name = (hwmon / "name").read_text().strip()
        except OSError:
            continue
        if name not in wanted_chips:
            continue

        fallback: float | None = None
        for temp_input in sorted(hwmon.glob("temp*_input")):
            try:
                value = int(temp_input.read_text().strip()) / 1000
            except (OSError, ValueError):
                continue
            label_file = temp_input.with_name(temp_input.name.replace("_input", "_label"))
            label = label_file.read_text().strip() if label_file.exists() else ""
            if label in wanted_labels:
                return round(value, 1)
            if fallback is None:
                fallback = value
        if fallback is not None:
            return round(fallback, 1)

    # Виртуалки и контейнеры: hwmon пуст, датчиков нет вовсе
    return None


cpu = CpuSampler()


def collect() -> dict[str, object]:
    ram_pct, ram_total = read_memory()
    disk_pct, disk_total = read_disk(DISK_PATH)
    temp = read_temperature()
    load1, load5, load15 = os.getloadavg()

    return {
        "state": "online",
        "cpu": cpu.percent(),
        "ram": ram_pct,
        "disk": disk_pct,
        "temperature": temp if temp is not None else 0,
        "uptimeSec": read_uptime(),
        "hostname": os.uname().nodename,
        "cores": os.cpu_count(),
        "loadAvg": [round(load1, 2), round(load5, 2), round(load15, 2)],
        "ramTotalBytes": ram_total,
        "diskTotalBytes": disk_total,
        "hasTemperature": temp is not None,
        "canWake": WAKE_ENABLED,
    }


def compute_alerts(m: dict[str, object]) -> list[dict[str, str]]:
    """Пороговые алерты по свежесобранным метрикам. Без состояния и истории —
    хост либо превышает порог прямо сейчас, либо нет. Пороги настраиваются
    с телефона через /alert-config (см. get_config/set_config выше)."""
    cfg = get_config()
    alerts: list[dict[str, str]] = []

    def add(id_: str, level: str, message: str) -> None:
        alerts.append({"id": id_, "level": level, "message": message})

    cpu = m["cpu"]
    if cpu >= cfg["cpu"]:
        add("cpu", "warning", f"Процессор загружен на {cpu}%")

    ram = m["ram"]
    if ram >= cfg["ram"]:
        add("ram", "warning", f"Память заполнена на {ram}%")

    disk = m["disk"]
    if disk >= cfg["disk"]:
        add("disk", "warning", f"Диск заполнен на {disk}%")

    if m["hasTemperature"] and m["temperature"] >= cfg["temperature"]:
        add("temperature", "warning", f"Температура процессора {m['temperature']}°C")

    return alerts


# --------------------------------------------------------------------------
# Nextcloud: фоновый опрос status.php + serverinfo, кэш состояния, свои алерты
# --------------------------------------------------------------------------

_nc_lock = threading.Lock()
# reachable=True на старте, чтобы не поднять ложный алерт «недоступно» до
# первого реального опроса; поток заменит его фактическим значением.
_nc_state: dict[str, object] = {"configured": bool(NC_URL), "reachable": True, "hasServerinfo": False}


def get_nc_state() -> dict[str, object]:
    with _nc_lock:
        return dict(_nc_state)


def _http_get_json(url: str, headers: dict[str, str] | None = None, timeout: int = 8) -> dict:
    import urllib.request

    req = urllib.request.Request(url, headers=headers or {}, method="GET")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode())


def _run_occ(subcmd: list[str], timeout: int = 25) -> tuple[int, str]:
    """Запускает occ через NC_OCC-префикс (обычно `docker exec ... php occ`).
    Возвращает (код возврата, stdout). Команда — из доверенной env, не из сети."""
    proc = subprocess.run(
        shlex.split(NC_OCC) + subcmd,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    return proc.returncode, proc.stdout or ""


def _occ_checks(state: dict[str, object]) -> None:
    """Дописывает в state результаты occ-проверок: обновление ядра и
    предупреждения настройки/безопасности. Требует доступ агента к occ
    (NC_OCC). Каждая проверка изолирована — сбой одной не рушит остальные."""
    if not NC_OCC:
        return

    # Обновление ядра Nextcloud (не приложений). Текст occ update:check меняется
    # между версиями — ориентируемся на «is available»; при отсутствии — ядро в норме.
    try:
        _, out = _run_occ(["update:check"])
        low = out.lower()
        available = "is available" in low or "are available" in low
        state["coreUpdateAvailable"] = bool(available)
        if available:
            m = re.search(r"Nextcloud\s+([0-9][0-9.]*)\s+is available", out)
            state["coreUpdateVersion"] = m.group(1) if m else None
    except (OSError, subprocess.SubprocessError):
        pass  # occ недоступен/таймаут — поле просто не выставляем

    # Предупреждения настройки/безопасности (occ setupchecks, NC 28+).
    # ВНИМАНИЕ: JSON-структура setupchecks зависит от версии — читаем защищённо.
    try:
        _, out = _run_occ(["setupchecks", "--output=json"])
        checks = json.loads(out)
        messages: list[str] = []
        items = checks.values() if isinstance(checks, dict) else (checks if isinstance(checks, list) else [])
        for item in items:
            if not isinstance(item, dict):
                continue
            severity = str(item.get("severity", "")).lower()
            passed = item.get("pass")
            is_problem = severity in ("warning", "error") or passed is False
            if is_problem:
                text = item.get("description") or item.get("name") or item.get("check") or "предупреждение"
                messages.append(str(text))
        state["warnings"] = messages
        state["warningsCount"] = len(messages)
    except (OSError, subprocess.SubprocessError, ValueError, TypeError):
        pass  # occ setupchecks нет (старая версия)/не JSON — поле не выставляем


def fetch_nextcloud() -> dict[str, object]:
    """Собирает состояние Nextcloud. status.php — без авторизации (доступность,
    режим обслуживания, версия). serverinfo — по токену приложения serverinfo
    (подробности: пользователи, файлы, шары, свободное место, обновления)."""
    state: dict[str, object] = {"configured": True, "reachable": False, "hasServerinfo": False}

    try:
        status = _http_get_json(f"{NC_URL}/status.php")
    except (OSError, ValueError):
        return state  # облако недоступно — reachable остаётся False

    state["reachable"] = bool(status.get("installed", False))
    state["maintenance"] = bool(status.get("maintenance", False))
    state["needsDbUpgrade"] = bool(status.get("needsDbUpgrade", False))
    state["version"] = status.get("versionstring") or status.get("version")
    state["productName"] = status.get("productname") or "Nextcloud"

    _occ_checks(state)  # обновление ядра + предупреждения (если задан NC_OCC)

    if not NC_TOKEN:
        return state  # только status.php + occ, без подробной статистики serverinfo

    try:
        info = _http_get_json(
            f"{NC_URL}/ocs/v2.php/apps/serverinfo/api/v1/info?format=json&token={NC_TOKEN}",
            headers={"OCS-APIRequest": "true", "Accept": "application/json"},
        )
        data = info["ocs"]["data"]
    except (OSError, ValueError, KeyError, TypeError):
        return state  # токен неверный/приложение выключено — остаёмся на status.php

    # Структура serverinfo немного меняется между версиями NC — читаем защищённо.
    nc = data.get("nextcloud", {}) if isinstance(data, dict) else {}
    system = nc.get("system", {}) if isinstance(nc, dict) else {}
    storage = nc.get("storage", {}) if isinstance(nc, dict) else {}
    shares = nc.get("shares", {}) if isinstance(nc, dict) else {}
    active = data.get("activeUsers", {}) if isinstance(data, dict) else {}
    apps = system.get("apps", {}) if isinstance(system, dict) else {}
    server = data.get("server", {}) if isinstance(data, dict) else {}
    php = server.get("php", {}) if isinstance(server, dict) else {}
    database = server.get("database", {}) if isinstance(server, dict) else {}

    def _int(v):
        try:
            return int(v)
        except (TypeError, ValueError):
            return None

    state["hasServerinfo"] = True
    state["activeUsers"] = {
        "last5min": _int(active.get("last5minutes")),
        "last1hour": _int(active.get("last1hour")),
        "last24hours": _int(active.get("last24hours")),
    }
    state["numUsers"] = _int(storage.get("num_users"))
    state["numFiles"] = _int(storage.get("num_files"))
    state["numShares"] = _int(shares.get("num_shares"))
    state["freeSpaceBytes"] = _int(storage.get("free_space"))
    state["appUpdates"] = _int(apps.get("num_updates_available")) or 0

    # Серверная техинфа (статичная, но полезно видеть версии и рост БД).
    state["phpVersion"] = php.get("version")
    state["webserver"] = server.get("webserver")
    db_type = database.get("type")
    db_version = database.get("version")
    if db_type:
        state["database"] = f"{db_type} {db_version}".strip() if db_version else str(db_type)
    state["dbSizeBytes"] = _int(database.get("size"))
    return state


def compute_nc_alerts(nc: dict[str, object]) -> list[dict[str, str]]:
    """Алерты по состоянию Nextcloud. Место на диске/CPU/RAM сервера уже
    покрыты обычными алертами машины, поэтому здесь — только NC-специфика."""
    if not nc.get("configured"):
        return []
    alerts: list[dict[str, str]] = []

    def add(id_: str, message: str) -> None:
        alerts.append({"id": id_, "level": "warning", "message": message})

    if not nc.get("reachable"):
        add("nc-unreachable", "Nextcloud недоступен")
        return alerts  # остальное неинформативно, если облако не отвечает

    if nc.get("maintenance"):
        add("nc-maintenance", "Nextcloud в режиме обслуживания")
    if nc.get("needsDbUpgrade"):
        add("nc-db-upgrade", "Nextcloud: требуется апгрейд базы данных")
    updates = nc.get("appUpdates")
    if isinstance(updates, int) and updates > 0:
        word = "обновление" if updates == 1 else "обновлений"
        add("nc-update", f"Nextcloud: доступно {updates} {word} приложений")
    if nc.get("coreUpdateAvailable"):
        version = nc.get("coreUpdateVersion")
        add("nc-core-update", f"Доступно обновление Nextcloud{f' {version}' if version else ''}")
    warnings = nc.get("warningsCount")
    if isinstance(warnings, int) and warnings > 0:
        word = "предупреждение" if warnings == 1 else "предупреждений"
        add("nc-warnings", f"Nextcloud: {warnings} {word} настройки/безопасности")
    return alerts


def all_alerts() -> list[dict[str, str]]:
    """Единый список алертов хоста: метрики машины + Nextcloud. Используется
    и в GET /alerts, и в watcher'е push — чтобы показ и push совпадали."""
    return compute_alerts(collect()) + compute_nc_alerts(get_nc_state())


def _nc_loop() -> None:
    """Раз в NC_INTERVAL секунд обновляет кэш состояния Nextcloud. Сам по себе
    push не шлёт — это делает watcher ntfy, беря NC-алерты из all_alerts()."""
    if not NC_URL:
        return
    while True:
        state = fetch_nextcloud()
        with _nc_lock:
            _nc_state.clear()
            _nc_state.update(state)
        time.sleep(NC_INTERVAL)


# --------------------------------------------------------------------------
# ntfy: фоновый watcher, публикует push при появлении нового алерта
# --------------------------------------------------------------------------

NTFY_URL = os.environ.get("PC_AGENT_NTFY_URL", "").rstrip("/")
WATCH_INTERVAL = int(os.environ.get("PC_AGENT_WATCH_INTERVAL", "10"))

_watch_lock = threading.Lock()
_active_alert_ids: set[str] = set()


def _publish_ntfy(topic: str, title: str, message: str) -> None:
    import urllib.request

    req = urllib.request.Request(
        f"{NTFY_URL}/{topic}",
        data=message.encode(),
        headers={"Title": title, "Priority": "high", "Tags": topic},
        method="POST",
    )
    urllib.request.urlopen(req, timeout=5)


def _watch_loop() -> None:
    """Раз в WATCH_INTERVAL секунд пересчитывает алерты и шлёт push в ntfy
    только для тех, что появились впервые с прошлого цикла (edge-triggered) —
    не спамит, пока условие остаётся в силе."""
    if not NTFY_URL:
        return
    while True:
        time.sleep(WATCH_INTERVAL)
        cfg = get_config()
        topic = cfg.get("ntfyTopic")
        if not topic:
            continue
        try:
            alerts = all_alerts()
        except Exception:
            continue

        ids = {a["id"] for a in alerts}
        with _watch_lock:
            newly = ids - _active_alert_ids
            _active_alert_ids.clear()
            _active_alert_ids.update(ids)

        for alert in alerts:
            if alert["id"] not in newly:
                continue
            try:
                _publish_ntfy(str(topic), os.uname().nodename, alert["message"])
            except OSError:
                pass  # доставка лучше-чем-ничего, не роняем поток


# --------------------------------------------------------------------------
# Wake-on-LAN
# --------------------------------------------------------------------------

def send_magic_packet(mac: str, broadcast: str = "255.255.255.255", port: int = 9) -> None:
    """Magic packet: шесть байт 0xFF, затем MAC, повторённый 16 раз."""
    raw = bytes.fromhex(mac.replace(":", "").replace("-", ""))
    packet = b"\xff" * 6 + raw * 16
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(packet, (broadcast, port))


# --------------------------------------------------------------------------
# HTTP
# --------------------------------------------------------------------------

class Handler(BaseHTTPRequestHandler):
    server_version = "PCAgent/1.0"

    def log_message(self, *args) -> None:
        pass  # не засоряем journal каждым опросом раз в 4 секунды

    def _json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _authorized(self) -> bool:
        header = self.headers.get("Authorization", "")
        supplied = header[7:] if header.startswith("Bearer ") else ""
        return secrets.compare_digest(supplied, TOKEN)

    def do_GET(self) -> None:
        if self.path == "/health":
            self._json(200, {"status": "ok"})
            return

        if not self._authorized():
            self._json(401, {"error": "Неверный токен"})
            return

        if self.path == "/metrics":
            self._json(200, collect())
        elif self.path == "/alerts":
            self._json(200, {"alerts": all_alerts()})
        elif self.path == "/alert-config":
            self._json(200, get_config())
        elif self.path == "/nextcloud":
            self._json(200, get_nc_state())
        else:
            self._json(404, {"error": "Не найдено"})

    def do_PUT(self) -> None:
        if not self._authorized():
            self._json(401, {"error": "Неверный токен"})
            return

        if self.path != "/alert-config":
            self._json(404, {"error": "Не найдено"})
            return

        length = int(self.headers.get("Content-Length", "0"))
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            self._json(400, {"error": "Тело запроса не является JSON"})
            return

        patch: dict[str, float | str | None] = {}
        bounds = {"cpu": (1, 100), "ram": (1, 100), "disk": (1, 100), "temperature": (1, 150)}
        for key, (lo, hi) in bounds.items():
            if key not in body:
                continue
            try:
                value = float(body[key])
            except (TypeError, ValueError):
                self._json(400, {"error": f"{key}: ожидается число"})
                return
            if not (lo <= value <= hi):
                self._json(400, {"error": f"{key}: диапазон {lo}-{hi}"})
                return
            patch[key] = value

        if "ntfyTopic" in body:
            topic = body["ntfyTopic"]
            patch["ntfyTopic"] = str(topic) if topic else None

        self._json(200, set_config(patch))

    def do_POST(self) -> None:
        if not self._authorized():
            self._json(401, {"error": "Неверный токен"})
            return

        if self.path != "/wake":
            self._json(404, {"error": "Не найдено"})
            return

        if not WAKE_ENABLED:
            self._json(403, {"error": "Пробуждение отключено на этом хосте"})
            return

        length = int(self.headers.get("Content-Length", "0"))
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            self._json(400, {"error": "Тело запроса не является JSON"})
            return

        mac = str(body.get("mac", ""))
        if not MAC_RE.match(mac):
            self._json(400, {"error": "MAC должен быть в формате 00:1A:2B:3C:4D:5E"})
            return

        broadcast = str(body.get("broadcast") or "255.255.255.255")
        port = int(body.get("port") or 9)

        try:
            send_magic_packet(mac, broadcast, port)
        except OSError as exc:
            self._json(502, {"error": f"Не удалось отправить пакет: {exc}"})
            return

        self._json(200, {"sent": True, "mac": mac.upper(), "broadcast": broadcast})


def main() -> None:
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    server.daemon_threads = True
    if NC_URL:
        threading.Thread(target=_nc_loop, daemon=True).start()
    if NTFY_URL:
        threading.Thread(target=_watch_loop, daemon=True).start()
    print(
        f"PC Agent слушает {HOST}:{PORT}, пробуждение: {'вкл' if WAKE_ENABLED else 'выкл'}, "
        f"Nextcloud: {'вкл' if NC_URL else 'выкл'}"
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()


if __name__ == "__main__":
    main()
