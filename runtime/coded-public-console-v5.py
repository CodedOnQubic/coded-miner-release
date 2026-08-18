#!/usr/bin/env python3
"""Canonical public CODED console for Anthill V5.

SOLS is fail-closed Qubic NETWORK_ACCEPTED truth.  Local score/pass counters are
never rendered as accepted solutions.
"""
from __future__ import annotations

import os
import re
import sys
import time
from typing import Dict, Optional

MARKER = "M1091V64A_NETWORK_ACCEPTED_PUBLIC_CONSOLE"
BRAND_EVERY = int(os.environ.get("CODED_PUBLIC_BRAND_EVERY", "9") or "9")
LINE_SEC = float(os.environ.get("CODED_PUBLIC_LINE_SEC", "1") or "1")
BRAND_WIDTH = max(56, int(os.environ.get("CODED_PUBLIC_BRAND_WIDTH", "78") or "78"))


def env_any(*names: str, default: str = "") -> str:
    for name in names:
        value = os.environ.get(name)
        if value is not None and str(value).strip():
            return str(value).strip()
    return default


def kv_parse(line: str) -> Dict[str, str]:
    out: Dict[str, str] = {}
    for key, value in re.findall(r'([A-Za-z0-9_]+)=("[^"]*"|[^ \t\r\n]+)', line):
        if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
            value = value[1:-1]
        out[key] = value
    return out


def fnum(value, default: float = 0.0) -> float:
    try:
        return float(str(value).strip()) if value is not None else default
    except Exception:
        return default


def inum(value, default: int = 0) -> int:
    try:
        return int(float(str(value).strip())) if value is not None else default
    except Exception:
        return default


def first_int(frame: Dict[str, str], *names: str) -> int:
    for name in names:
        value = frame.get(name)
        if value is not None and str(value).strip():
            return inum(value, 0)
    return 0


def network_accepted(frame: Dict[str, str]) -> int:
    # Deliberately forbidden: total_pass, solutions, sols, real300, real310,
    # real321, accepted, accepted_total and total_accepted.
    return first_int(
        frame,
        "network_accepted_total",
        "network_accepted_solutions",
        "network_accepted",
        "qubic_network_accepted_total",
        "qubic_network_accepted",
    )


def network_rejected(frame: Dict[str, str]) -> int:
    return first_int(
        frame,
        "network_rejected_total",
        "network_rejected_solutions",
        "network_rejected",
        "qubic_network_rejected_total",
        "qubic_network_rejected",
    )


def fmt_rate(value: float) -> str:
    value = float(value or 0.0)
    if value >= 1_000_000_000:
        text = f"{value / 1_000_000_000:.2f}G"
    elif value >= 1_000_000:
        text = f"{value / 1_000_000:.2f}M"
    elif value >= 1_000:
        text = f"{value / 1_000:.2f}K"
    else:
        text = f"{value:.0f}"
    return text.replace(".", ",")


def backend_label(raw: str, platform: str) -> str:
    value = (raw or "").lower()
    host = (platform or "").lower()
    if "hybrid" in value or "neon+metal" in value:
        return "NEON/METAL"
    if "metal" in value:
        return "METAL"
    if "neon" in value:
        return "NEON"
    if "cuda" in value:
        return "CUDA"
    if "avx512" in value or "avx-512" in value:
        return "AVX512"
    if "avx2" in value:
        return "AVX2"
    if "arm" in value or host.startswith("macos-arm") or host.startswith("darwin"):
        return "ARM"
    return "SCALAR"


def epoch_or_fallback(value: str) -> str:
    value = (value or "").strip()
    if value and value.lower() not in ("auto", "none", "null", "unknown"):
        return value
    try:
        import calendar
        ref = calendar.timegm(time.strptime("2026-07-01 12:00:00", "%Y-%m-%d %H:%M:%S"))
        return str(220 + int((time.time() - ref) // 604800))
    except Exception:
        return "?"


def print_brand() -> None:
    title = "$0.01  IS  CODED"
    line = "═" * BRAND_WIDTH
    pad = max(0, BRAND_WIDTH - len(title))
    left = pad // 2
    right = pad - left
    print("")
    print(f"╔{line}╗")
    print(f"║{' ' * left}{title}{' ' * right}║")
    print(f"╚{line}╝")
    print("", flush=True)


class PublicState:
    def __init__(self) -> None:
        self.worker = env_any("CODED_WORKER_NAME", "WORKER", "RIG_ID", "CODED_RIG_ID", default="coded-worker")
        self.wallet = env_any("CODED_WALLET", "WALLET", "QUBIC_WALLET", default="not set")
        self.threads = env_any("CODED_THREADS", "THREADS", default="?")
        self.env_backend = env_any("CODED_SELECTED_BACKEND", "CODED_KERNEL_BACKEND", "CODED_BACKEND", "BACKEND", default="")
        self.frame_backend = ""
        self.platform = env_any("CODED_PLATFORM", default=sys.platform)
        self.epoch = epoch_or_fallback(env_any("QUBIC_EPOCH", "CODED_EPOCH", "CODED_PUBLIC_EPOCH", default="?"))
        self.printed_header = False
        self.status_count = 0
        self.latest_frame: Optional[Dict[str, str]] = None
        self.last_emit = 0.0

    def backend(self) -> str:
        return backend_label(self.env_backend or self.frame_backend, self.platform)

    def update_line(self, line: str) -> None:
        data = kv_parse(line)
        self.worker = data.get("worker") or self.worker
        self.threads = data.get("threads") or self.threads
        self.platform = data.get("platform") or self.platform
        self.frame_backend = data.get("backend") or self.frame_backend
        if data.get("epoch"):
            self.epoch = epoch_or_fallback(data["epoch"])

    def update_frame(self, frame: Dict[str, str]) -> None:
        self.worker = frame.get("worker") or self.worker
        self.threads = frame.get("threads") or self.threads
        self.platform = frame.get("platform") or self.platform
        self.frame_backend = frame.get("backend") or self.frame_backend
        self.epoch = epoch_or_fallback(frame.get("epoch") or self.epoch)
        self.latest_frame = frame

    def header(self) -> None:
        if self.printed_header:
            return
        print_brand()
        print("CODED PUBLIC MINER")
        print(f"wallet  : {self.wallet}")
        print(f"worker  : {self.worker}")
        print(f"threads : {self.threads}")
        print(f"backend : {self.backend()}")
        print(f"epoch   : {self.epoch}")
        print("")
        self.printed_header = True
        sys.stdout.flush()

    def render(self) -> None:
        if not self.latest_frame:
            return
        now = time.time()
        if now - self.last_emit < LINE_SEC:
            return
        self.last_emit = now
        self.header()
        self.status_count += 1
        if self.status_count > 1 and (self.status_count - 1) % BRAND_EVERY == 0:
            print_brand()

        frame = self.latest_frame
        total = fnum(
            frame.get("hash_it_s")
            or frame.get("total_it_s")
            or frame.get("raw_it_s")
            or frame.get("backend_hotloop_it_s")
            or frame.get("pipeline_it_s")
        )
        avg = fnum(frame.get("avg_hash_it_s_30s"), total)
        accepted = network_accepted(frame)
        rejected = network_rejected(frame)
        sols = accepted
        clock = time.strftime("%H:%M:%S", time.localtime())
        epoch = epoch_or_fallback(frame.get("epoch") or self.epoch)
        total_s = fmt_rate(total)
        avg_s = fmt_rate(avg)
        logo = "[$0.01]"
        body = f"{clock} E:{str(epoch):>3} | SOLS {sols}/{accepted} R:{rejected} | {self.backend()} | {total_s} it/s | AVG {avg_s} it/s"
        gap = BRAND_WIDTH - len(logo) - len(body)
        if gap < 1:
            body = f"{clock} E:{str(epoch):>3} | S {sols}/{accepted} R:{rejected} | {self.backend()} | {total_s} it/s | AVG {avg_s} it/s"
            gap = BRAND_WIDTH - len(logo) - len(body)
        if gap < 1:
            body = f"{clock} E:{str(epoch):>3}|S{sols}/{accepted} R{rejected}|{self.backend()}|{total_s} it/s|AVG {avg_s} it/s"
            gap = max(1, BRAND_WIDTH - len(logo) - len(body))
        print((logo + " " * gap + body)[:BRAND_WIDTH].ljust(BRAND_WIDTH), flush=True)


def process_line(state: PublicState, line: str) -> None:
    state.update_line(line)
    if "[CODED_ANALYTICS_FRAME]" in line:
        frame = kv_parse(line)
        if frame:
            state.update_frame(frame)


def pid_alive(pid: int) -> bool:
    if pid <= 0:
        return True
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except Exception:
        return False


def follow(path: str, child_pid: int) -> int:
    state = PublicState()
    state.header()
    pos = 0
    quiet_after_exit = 0
    while True:
        try:
            with open(path, "r", errors="replace") as stream:
                stream.seek(pos)
                while True:
                    line = stream.readline()
                    if not line:
                        break
                    pos = stream.tell()
                    process_line(state, line.rstrip("\n"))
        except FileNotFoundError:
            pass
        state.render()
        if child_pid > 0 and not pid_alive(child_pid):
            quiet_after_exit += 1
            if quiet_after_exit >= 4:
                return 0
        else:
            quiet_after_exit = 0
        time.sleep(0.20)


def main() -> int:
    if len(sys.argv) < 2:
        print(f"{MARKER}: usage coded-public-console-v5.py INTERNAL_LOG [CHILD_PID]", file=sys.stderr)
        return 2
    child_pid = 0
    if len(sys.argv) >= 3:
        try:
            child_pid = int(sys.argv[2])
        except Exception:
            pass
    try:
        return follow(sys.argv[1], child_pid)
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
