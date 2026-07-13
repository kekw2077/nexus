#!/usr/bin/env python3
"""
PC Agent (Windows) — метрики основного ПК + ретранслятор Wake-on-LAN.

Windows-близнец `agent slim.py` (тот только для Linux: /proc, statvfs, uname).
Отдаёт точно тот же HTTP-контракт, что ждёт приложение Nexus, поэтому ПК
появляется в мониторинге наравне с сервером. Только стандартная библиотека:
метрики читаются через WinAPI (ctypes), GPU — через nvidia-smi (идёт с драйвером
NVIDIA). Ни pip, ни venv не нужны.

    GET  /health          без токена, "жив ли хост" (+ hostname для поиска в сети)
    GET  /metrics         cpu / ram / disk / temperature(GPU) / uptimeSec (+ gpu*)
    GET  /alerts          пороги превышены прямо сейчас
    GET  /alert-config    текущие пороги + топик ntfy для этого хоста
    PUT  /alert-config    задать пороги/топик с телефона — источник истины телефон
    POST /wake            {"mac": "00:1A:2B:3C:4D:5E", "broadcast": "192.168.1.255"}

Запуск (PowerShell):
    $env:PC_AGENT_TOKEN="ваш-токен"; python agent_pc.py
Без консольного окна (автозапуск):
    $env:PC_AGENT_TOKEN="ваш-токен"; pythonw agent_pc.py

Push-уведомления (опционально): задайте PC_AGENT_NTFY_URL (адрес self-hosted
ntfy) — фоновый поток раз в PC_AGENT_WATCH_INTERVAL секунд (по умолчанию 10)
шлёт push в топик из PUT /alert-config (ntfyTopic) при появлении нового алерта.

Температура: на Windows без сторонних библиотек доступна температура GPU
(nvidia-smi), она и кладётся в поле temperature. Температуру CPU штатными
средствами не получить (нужен LibreHardwareMonitor и т.п.) — намеренно не тянем
зависимости. GPU-загрузка и VRAM отдаются дополнительными полями (gpu, vram*).
"""

from __future__ import annotations

import ctypes
import json
import os
import re
import secrets
import socket
import subprocess
import threading
import time
from ctypes import wintypes
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

TOKEN = os.environ.get("PC_AGENT_TOKEN", "")
HOST = os.environ.get("PC_AGENT_HOST", "0.0.0.0")
PORT = int(os.environ.get("PC_AGENT_PORT", "8765"))
DISK_PATH = os.environ.get("PC_AGENT_DISK", "C:\\")
WAKE_ENABLED = os.environ.get("PC_AGENT_WAKE", "1") == "1"

ALERT_CPU = int(os.environ.get("PC_AGENT_ALERT_CPU", "90"))
ALERT_RAM = int(os.environ.get("PC_AGENT_ALERT_RAM", "90"))
ALERT_DISK = int(os.environ.get("PC_AGENT_ALERT_DISK", "90"))
ALERT_TEMP = float(os.environ.get("PC_AGENT_ALERT_TEMP", "85"))

STATE_PATH = Path(os.environ.get("PC_AGENT_STATE_FILE", "pc-agent-config.json"))

if not TOKEN:
    raise SystemExit(
        "PC_AGENT_TOKEN не задан. Сгенерируйте и задайте, например в PowerShell:\n"
        f'  $env:PC_AGENT_TOKEN="{secrets.token_urlsafe(24)}"'
    )

MAC_RE = re.compile(r"^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$")

# Прячем окно консоли у дочерних процессов (nvidia-smi), если запущены из GUI.
_NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)


# --------------------------------------------------------------------------
# Настраиваемые с телефона пороги + топик ntfy. Телефон — источник истины:
# env ALERT_* — лишь seed-значения на первый запуск, если файла состояния нет.
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
# Метрики: WinAPI через ctypes (без сторонних пакетов)
# --------------------------------------------------------------------------

_kernel32 = ctypes.windll.kernel32 if os.name == "nt" else None


class _FILETIME(ctypes.Structure):
    _fields_ = [("dwLowDateTime", wintypes.DWORD), ("dwHighDateTime", wintypes.DWORD)]


class _MEMORYSTATUSEX(ctypes.Structure):
    _fields_ = [
        ("dwLength", wintypes.DWORD),
        ("dwMemoryLoad", wintypes.DWORD),
        ("ullTotalPhys", ctypes.c_ulonglong),
        ("ullAvailPhys", ctypes.c_ulonglong),
        ("ullTotalPageFile", ctypes.c_ulonglong),
        ("ullAvailPageFile", ctypes.c_ulonglong),
        ("ullTotalVirtual", ctypes.c_ulonglong),
        ("ullAvailVirtual", ctypes.c_ulonglong),
        ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
    ]


def _ft_to_int(ft: _FILETIME) -> int:
    return (ft.dwHighDateTime << 32) | ft.dwLowDateTime


class CpuSampler:
    """
    GetSystemTimes отдаёт накопленные счётчики (idle/kernel/user), а не проценты.
    Занятость — дельта между двумя чтениями, поэтому храним предыдущее.
    kernel уже включает idle, значит total = kernel + user, busy = 1 - idle/total.
    """

    def __init__(self) -> None:
        self._prev = self._read()

    @staticmethod
    def _read() -> tuple[int, int]:
        idle, kernel, user = _FILETIME(), _FILETIME(), _FILETIME()
        ok = _kernel32.GetSystemTimes(ctypes.byref(idle), ctypes.byref(kernel), ctypes.byref(user))
        if not ok:
            raise OSError("GetSystemTimes не выполнился")
        return _ft_to_int(kernel) + _ft_to_int(user), _ft_to_int(idle)

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
    """(процент занятого, всего байт). dwMemoryLoad — готовый процент от WinAPI."""
    stat = _MEMORYSTATUSEX()
    stat.dwLength = ctypes.sizeof(_MEMORYSTATUSEX)
    if not _kernel32.GlobalMemoryStatusEx(ctypes.byref(stat)):
        raise OSError("GlobalMemoryStatusEx не выполнился")
    return int(stat.dwMemoryLoad), int(stat.ullTotalPhys)


def _disk_usage(path: str) -> tuple[int, int, int]:
    """(процент занятого, всего байт, занято байт) для тома с path."""
    free_avail = ctypes.c_ulonglong(0)
    total = ctypes.c_ulonglong(0)
    total_free = ctypes.c_ulonglong(0)
    ok = _kernel32.GetDiskFreeSpaceExW(
        ctypes.c_wchar_p(path),
        ctypes.byref(free_avail),
        ctypes.byref(total),
        ctypes.byref(total_free),
    )
    if not ok:
        raise OSError("GetDiskFreeSpaceExW не выполнился")
    total_bytes = total.value
    used = total_bytes - total_free.value
    percent = round(100 * used / total_bytes) if total_bytes else 0
    return percent, total_bytes, used


def read_disk(path: str) -> tuple[int, int]:
    """(процент занятого, всего байт) для тома, которому принадлежит path."""
    percent, total, _ = _disk_usage(path)
    return percent, total


def read_disks() -> list[dict[str, object]]:
    """Все фиксированные диски системы (C:, D:, …). Сетевые/съёмные/CD — мимо."""
    _DRIVE_FIXED = 3
    disks: list[dict[str, object]] = []
    bitmask = _kernel32.GetLogicalDrives()
    for i in range(26):
        if not (bitmask >> i) & 1:
            continue
        root = f"{chr(65 + i)}:\\"
        if _kernel32.GetDriveTypeW(ctypes.c_wchar_p(root)) != _DRIVE_FIXED:
            continue
        try:
            percent, total, used = _disk_usage(root)
        except OSError:
            continue
        disks.append({"name": f"{chr(65 + i)}:", "percent": percent, "totalBytes": total, "usedBytes": used})
    return disks


def read_cpu_temp() -> float | None:
    """Best-effort температура CPU через ACPI-датчик (WMI MSAcpi_ThermalZoneTemperature).
    На многих платах датчик недоступен/врёт — тогда None (это норма для Windows;
    точная температура CPU требует LibreHardwareMonitor и т.п., которые мы не тянем)."""
    try:
        proc = subprocess.run(
            [
                "powershell", "-NoProfile", "-Command",
                "(Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature "
                "-ErrorAction Stop | Select-Object -First 1 -ExpandProperty CurrentTemperature)",
            ],
            capture_output=True,
            text=True,
            timeout=6,
            creationflags=_NO_WINDOW,
        )
        out = proc.stdout.strip()
        if proc.returncode != 0 or not out:
            return None
        celsius = float(out.splitlines()[0]) / 10 - 273.15
        if celsius <= 0 or celsius >= 125:
            return None  # явно мусорное значение датчика
        return round(celsius, 1)
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def read_uptime() -> int:
    _kernel32.GetTickCount64.restype = ctypes.c_ulonglong
    return int(_kernel32.GetTickCount64() // 1000)


def read_gpu() -> dict[str, object] | None:
    """Температура/загрузка/VRAM GPU через nvidia-smi (идёт с драйвером NVIDIA).
    None, если nvidia-smi недоступен (нет NVIDIA-карты) — тогда без температуры."""
    try:
        proc = subprocess.run(
            [
                "nvidia-smi",
                "--query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total",
                "--format=csv,noheader,nounits",
            ],
            capture_output=True,
            text=True,
            timeout=5,
            creationflags=_NO_WINDOW,
        )
        if proc.returncode != 0 or not proc.stdout.strip():
            return None
        first = proc.stdout.strip().splitlines()[0]
        temp, util, mem_used, mem_total = [p.strip() for p in first.split(",")]
        return {
            "gpuTemp": float(temp),
            "gpu": round(float(util)),
            "vramUsedBytes": int(float(mem_used)) * 1024 * 1024,
            "vramTotalBytes": int(float(mem_total)) * 1024 * 1024,
        }
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


cpu = CpuSampler()


def collect() -> dict[str, object]:
    ram_pct, ram_total = read_memory()
    disks = read_disks()
    gpu = read_gpu()
    cpu_temp = read_cpu_temp()
    gpu_temp = gpu["gpuTemp"] if gpu is not None else None

    # legacy disk/diskTotalBytes — системный том (DISK_PATH), иначе самый полный.
    try:
        disk_pct, disk_total = read_disk(DISK_PATH)
    except OSError:
        if disks:
            primary = max(disks, key=lambda d: d["percent"])
            disk_pct, disk_total = int(primary["percent"]), int(primary["totalBytes"])
        else:
            disk_pct, disk_total = 0, 0

    legacy_temp = cpu_temp if cpu_temp is not None else gpu_temp

    metrics: dict[str, object] = {
        "state": "online",
        "cpu": cpu.percent(),
        "ram": ram_pct,
        "disk": disk_pct,
        "disks": disks,
        "temperature": legacy_temp if legacy_temp is not None else 0,
        "uptimeSec": read_uptime(),
        "hostname": socket.gethostname(),
        "cores": os.cpu_count(),
        "loadAvg": [],  # у Windows нет loadavg — приложение это переживает
        "ramTotalBytes": ram_total,
        "diskTotalBytes": disk_total,
        "hasTemperature": legacy_temp is not None,
        "canWake": WAKE_ENABLED,
    }
    if cpu_temp is not None:
        metrics["cpuTemp"] = cpu_temp
    if gpu is not None:
        # gpuTemp + доп. поля gpu/vram* (текущий UI показывает только gpuTemp).
        metrics.update(gpu)
    return metrics


def compute_alerts(m: dict[str, object]) -> list[dict[str, str]]:
    """Пороговые алерты по свежим метрикам. Без истории: превышает сейчас или нет.
    Пороги настраиваются с телефона через /alert-config."""
    cfg = get_config()
    alerts: list[dict[str, str]] = []

    def add(id_: str, level: str, message: str) -> None:
        alerts.append({"id": id_, "level": level, "message": message})

    if m["cpu"] >= cfg["cpu"]:
        add("cpu", "warning", f"Процессор загружен на {m['cpu']}%")
    if m["ram"] >= cfg["ram"]:
        add("ram", "warning", f"Память заполнена на {m['ram']}%")

    disks = m.get("disks") or []
    if disks:
        for d in disks:
            if d["percent"] >= cfg["disk"]:
                add(f"disk:{d['name']}", "warning", f"Диск {d['name']} заполнен на {d['percent']}%")
    elif m["disk"] >= cfg["disk"]:
        add("disk", "warning", f"Диск заполнен на {m['disk']}%")

    cpu_temp = m.get("cpuTemp")
    if cpu_temp is not None and cpu_temp >= cfg["temperature"]:
        add("temperature-cpu", "warning", f"Температура ЦП {cpu_temp}°C")

    gpu_temp = m.get("gpuTemp")
    if gpu_temp is not None and gpu_temp >= cfg["temperature"]:
        add("temperature-gpu", "warning", f"Температура ГП {gpu_temp}°C")

    return alerts


def all_alerts() -> list[dict[str, str]]:
    """На ПК нет Nextcloud — только пороговые алерты по метрикам."""
    return compute_alerts(collect())


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
    """Раз в WATCH_INTERVAL секунд пересчитывает алерты и шлёт push в ntfy только
    для появившихся впервые с прошлого цикла (edge-triggered) — не спамит."""
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
                _publish_ntfy(str(topic), socket.gethostname(), alert["message"])
            except OSError:
                pass  # доставка лучше-чем-ничего, не роняем поток


# --------------------------------------------------------------------------
# Wake-on-LAN (ПК тоже может быть ретранслятором для других машин)
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
    server_version = "PCAgentWin/1.0"

    def log_message(self, *args) -> None:
        pass  # не засоряем вывод каждым опросом

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
            # hostname без токена — чтобы поиск в приложении показывал имя, не IP.
            self._json(200, {"status": "ok", "hostname": socket.gethostname()})
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
    if os.name != "nt":
        raise SystemExit("agent_pc.py рассчитан на Windows. Для Linux — «agent slim.py».")

    server = ThreadingHTTPServer((HOST, PORT), Handler)
    server.daemon_threads = True
    if NTFY_URL:
        threading.Thread(target=_watch_loop, daemon=True).start()
    print(
        f"PC Agent (Windows) слушает {HOST}:{PORT}, "
        f"пробуждение: {'вкл' if WAKE_ENABLED else 'выкл'}, "
        f"push: {'вкл' if NTFY_URL else 'выкл'}"
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()


if __name__ == "__main__":
    main()
