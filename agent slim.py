#!/usr/bin/env python3
"""
PC Agent — метрики Ubuntu + ретранслятор Wake-on-LAN.
Только стандартная библиотека. Ни pip, ни venv не нужны.

    GET  /health          без токена, "жив ли хост"
    GET  /metrics         cpu / ram / disk / temperature / uptimeSec
    GET  /alerts          проблемы хоста: пороги cpu/ram/disk/temperature превышены
    POST /wake            {"mac": "00:1A:2B:3C:4D:5E", "broadcast": "192.168.1.255"}

Запуск:
    PC_AGENT_TOKEN=... python3 agent.py
"""

from __future__ import annotations

import json
import os
import re
import secrets
import socket
import struct
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

if not TOKEN:
    raise SystemExit(
        "PC_AGENT_TOKEN не задан. Сгенерируйте:\n"
        f"  export PC_AGENT_TOKEN={secrets.token_urlsafe(24)}"
    )

MAC_RE = re.compile(r"^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$")


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
    хост либо превышает порог прямо сейчас, либо нет."""
    alerts: list[dict[str, str]] = []

    def add(id_: str, level: str, message: str) -> None:
        alerts.append({"id": id_, "level": level, "message": message})

    cpu = m["cpu"]
    if cpu >= ALERT_CPU:
        add("cpu", "warning", f"Процессор загружен на {cpu}%")

    ram = m["ram"]
    if ram >= ALERT_RAM:
        add("ram", "warning", f"Память заполнена на {ram}%")

    disk = m["disk"]
    if disk >= ALERT_DISK:
        add("disk", "warning", f"Диск заполнен на {disk}%")

    if m["hasTemperature"] and m["temperature"] >= ALERT_TEMP:
        add("temperature", "warning", f"Температура процессора {m['temperature']}°C")

    return alerts


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
            self._json(200, {"alerts": compute_alerts(collect())})
        else:
            self._json(404, {"error": "Не найдено"})

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
    print(f"PC Agent слушает {HOST}:{PORT}, пробуждение: {'вкл' if WAKE_ENABLED else 'выкл'}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()


if __name__ == "__main__":
    main()
