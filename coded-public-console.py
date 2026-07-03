#!/usr/bin/env python3
# M1091V32C_PUBLIC_CONSOLE_POLISH

import os
import re
import sys
import time
from typing import Dict, Optional

MARKER = "M1091V32C_PUBLIC_CONSOLE_POLISH"

BRAND_EVERY = int(os.environ.get("CODED_PUBLIC_BRAND_EVERY", "9") or "9")
LINE_SEC = float(os.environ.get("CODED_PUBLIC_LINE_SEC", "1") or "1")
BRAND_WIDTH = int(os.environ.get("CODED_PUBLIC_BRAND_WIDTH", "78") or "78")

if BRAND_WIDTH < 56:
    BRAND_WIDTH = 56


def env_any(*names: str, default: str = "") -> str:
    for n in names:
        v = os.environ.get(n)
        if v is not None and str(v).strip() != "":
            return str(v).strip()
    return default


def kv_parse(line: str) -> Dict[str, str]:
    out: Dict[str, str] = {}
    for k, v in re.findall(r'([A-Za-z0-9_]+)=("[^"]*"|[^ \t\r\n]+)', line):
        if len(v) >= 2 and v[0] == '"' and v[-1] == '"':
            v = v[1:-1]
        out[k] = v
    return out


def fnum(v, default: float = 0.0) -> float:
    try:
        if v is None:
            return default
        return float(str(v).strip())
    except Exception:
        return default


def inum(v, default: int = 0) -> int:
    try:
        if v is None:
            return default
        return int(float(str(v).strip()))
    except Exception:
        return default


def fmt_rate(v: float) -> str:
    v = float(v or 0.0)

    if v >= 1_000_000_000:
        s = f"{v / 1_000_000_000:.2f}G"
    elif v >= 1_000_000:
        s = f"{v / 1_000_000:.2f}M"
    elif v >= 1_000:
        s = f"{v / 1_000:.2f}K"
    else:
        s = f"{v:.0f}"

    return s.replace(".", ",")


def canon_backend(raw: str, platform: str = "") -> str:
    r = (raw or "").strip().lower()
    p = (platform or "").strip().lower()

    if "cuda" in r:
        return "CUDA"
    if "avx512" in r or "avx-512" in r:
        return "AVX512"
    if "avx2" in r:
        return "AVX2"
    if "arm" in r or "neon" in r or p.startswith("macos-arm") or p.startswith("darwin"):
        return "ARM"

    return "SCALAR"


def clean_epoch(v: str) -> str:
    v = (v or "").strip()
    if not v or v.lower() in ("auto", "none", "null", "unknown"):
        return "?"
    return v


def current_qubic_epoch_fallback() -> str:
    # M1091V32F_EPOCH_FALLBACK_SHORT_STATUS_LINE
    # Qubic epoch changes weekly on Wednesday 12:00 UTC.
    # User-verified reference: epoch 220 is active after 2026-07-01 12:00 UTC.
    try:
        ref_epoch = 220
        ref_utc = time.mktime(time.strptime("2026-07-01 12:00:00", "%Y-%m-%d %H:%M:%S"))
        # time.mktime uses local time. Correct by using timezone offset via calendar-free UTC approximation.
        # Safer: build UTC timestamp with Python datetime if available.
        import calendar
        ref_tuple = time.strptime("2026-07-01 12:00:00", "%Y-%m-%d %H:%M:%S")
        ref_ts = calendar.timegm(ref_tuple)
        now_ts = time.time()
        delta_weeks = int((now_ts - ref_ts) // 604800)
        return str(ref_epoch + delta_weeks)
    except Exception:
        return "?"


def epoch_or_fallback(v: str) -> str:
    cleaned = clean_epoch(v)
    if cleaned != "?":
        return cleaned
    return current_qubic_epoch_fallback()


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

    def backend_label(self) -> str:
        source = self.env_backend or self.frame_backend
        return canon_backend(source, self.platform)

    def update_from_any_line(self, line: str) -> None:
        data = kv_parse(line)

        if data.get("worker"):
            self.worker = data["worker"]
        if data.get("threads"):
            self.threads = data["threads"]
        if data.get("platform"):
            self.platform = data["platform"]
        if data.get("epoch"):
            self.epoch = epoch_or_fallback(data["epoch"])
        if data.get("backend"):
            self.frame_backend = data["backend"]

    def update_from_frame(self, frame: Dict[str, str]) -> None:
        self.worker = frame.get("worker") or self.worker
        self.frame_backend = frame.get("backend") or self.frame_backend
        self.threads = frame.get("threads") or self.threads
        self.platform = frame.get("platform") or self.platform
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
        print(f"backend : {self.backend_label()}")
        print(f"epoch   : {self.epoch}")
        print("")

        self.printed_header = True
        sys.stdout.flush()

    def render_latest(self) -> None:
        if not self.latest_frame:
            return

        now = time.time()
        if (now - self.last_emit) < LINE_SEC:
            return

        self.last_emit = now

        if not self.printed_header:
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

        sols = inum(
            frame.get("solutions")
            or frame.get("sols")
            or frame.get("total_pass")
            or frame.get("real300")
            or 0
        )

        accepted = inum(
            frame.get("accepted")
            or frame.get("pool_accepted")
            or frame.get("accepted_total")
            or frame.get("total_accepted")
            or frame.get("accepted_solutions")
            or frame.get("total_pass")
            or 0
        )

        rejected = inum(
            frame.get("rejected")
            or frame.get("pool_rejected")
            or frame.get("rejected_total")
            or frame.get("total_rejected")
            or 0
        )

        clock = time.strftime("%H:%M:%S", time.localtime())
        epoch = epoch_or_fallback(frame.get("epoch") or self.epoch)
        backend = self.backend_label()

        # M1091V32M_DYNAMIC_GAP_AFTER_LOGO
        # Keep log lines unboxed and exactly as wide as the branding inner width.
        # Any spare space is placed after [$0.01], so hashrate/SOLS changes shrink/grow
        # the visual gap without moving the right edge.
        total_s = fmt_rate(total)
        avg_s = fmt_rate(avg)

        logo = "[$0.01]"
        body = (
            f"{clock} E:{str(epoch):>3} | "
            f"SOLS {sols}/{accepted} R:{rejected} | "
            f"{backend} | "
            f"{total_s} it/s | AVG {avg_s} it/s"
        )

        gap = BRAND_WIDTH - len(logo) - len(body)
        if gap < 1:
            body = (
                f"{clock} E:{str(epoch):>3} | "
                f"S {sols}/{accepted} R:{rejected} | "
                f"{backend} | "
                f"{total_s} it/s | AVG {avg_s} it/s"
            )
            gap = BRAND_WIDTH - len(logo) - len(body)

        if gap < 1:
            body = (
                f"{clock} E:{str(epoch):>3}|"
                f"S{sols}/{accepted} R{rejected}|"
                f"{backend}|"
                f"{total_s} it/s|AVG {avg_s} it/s"
            )
            gap = BRAND_WIDTH - len(logo) - len(body)

        if gap < 1:
            gap = 1

        status_line = logo + (" " * gap) + body

        if len(status_line) > BRAND_WIDTH:
            status_line = status_line[:BRAND_WIDTH]

        print(status_line.ljust(BRAND_WIDTH), flush=True)


def process_line(state: PublicState, line: str) -> None:
    state.update_from_any_line(line)

    if "[CODED_ANALYTICS_FRAME]" not in line:
        return

    frame = kv_parse(line)
    if not frame:
        return

    state.update_from_frame(frame)


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


def follow(path: str, child_pid: int = 0) -> int:
    state = PublicState()
    state.header()

    pos = 0
    quiet_after_exit = 0

    while True:
        try:
            with open(path, "r", errors="replace") as f:
                f.seek(pos)

                while True:
                    line = f.readline()
                    if not line:
                        break

                    pos = f.tell()
                    process_line(state, line.rstrip("\n"))
        except FileNotFoundError:
            pass

        state.render_latest()

        if child_pid > 0 and not pid_alive(child_pid):
            quiet_after_exit += 1
            if quiet_after_exit >= 4:
                return 0
        else:
            quiet_after_exit = 0

        time.sleep(0.20)


def main() -> int:
    if len(sys.argv) < 2:
        print(f"{MARKER}: usage coded-public-console.py INTERNAL_LOG [CHILD_PID]", file=sys.stderr)
        return 2

    path = sys.argv[1]

    child_pid = 0
    if len(sys.argv) >= 3:
        try:
            child_pid = int(sys.argv[2])
        except Exception:
            child_pid = 0

    try:
        return follow(path, child_pid)
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
