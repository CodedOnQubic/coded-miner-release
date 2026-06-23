#!/usr/bin/env python3
from dataclasses import dataclass
import os

def env(name, default=""):
    return os.environ.get(name) or default

def int_env(name, default=0):
    try:
        return int(os.environ.get(name) or default)
    except Exception:
        return default

@dataclass(frozen=True)
class Identity:
    rig_id: str
    worker_name: str
    api: str
    backend: str
    platform: str
    arch: str
    router: str
    matrix: str
    epoch: int
    threshold: int
    threads: int
    poll_sec: int

def load_identity():
    platform = env("CODED_PLATFORM", env("CODED_BACKEND_PLATFORM", "unknown"))
    backend = env("CODED_KERNEL_BACKEND", env("CODED_BACKEND", "unknown"))

    if "arm" in platform.lower() or "arm" in backend.lower() or "macos" in platform.lower():
        arch = "arm64"
    elif "avx" in backend.lower() or "x86" in platform.lower():
        arch = "x86_64"
    else:
        arch = env("CODED_ARCH", "unknown")

    return Identity(
        rig_id=env("RIG_ID", env("CODED_RIG_ID", "unknown")),
        worker_name=env("WORKER_NAME", env("CODED_WORKER_NAME", env("CODED_WORKER", "unknown"))),
        api=env("CODED_POOL_API_BASE", env("CODED_API_BASE", env("CODED_BACKEND_URL", "http://178.104.150.57:4000"))).rstrip("/"),
        backend=backend,
        platform=platform,
        arch=arch,
        router=env("CODED_PRIORITY_BUDGET_ROUTER", env("CODED_ROUTER", "sidecar")),
        matrix=env("CODED_PRIORITY_BUDGET_MATRIX", env("CODED_ROUTER_MATRIX", "sidecar")),
        epoch=int_env("QUBIC_EPOCH", int_env("CODED_EPOCH", 218)),
        threshold=int_env("CODED_FAST_SHADOW_THRESHOLD", int_env("CODED_THRESHOLD", int_env("THRESHOLD", 509))),
        threads=int_env("CODED_THREADS", int_env("THREADS", 0)),
        poll_sec=int_env("CODED_RUNTIME_SIDECAR_SEC", 30),
    )
