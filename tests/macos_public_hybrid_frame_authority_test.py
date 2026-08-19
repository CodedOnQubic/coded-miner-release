#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONSOLE = ROOT / "runtime" / "coded-public-console-v5.py"
RUNSH = ROOT / "run.sh"

spec = importlib.util.spec_from_file_location("coded_public_console_v5", CONSOLE)
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    old = dict(os.environ)
    try:
        os.environ["CODED_SELECTED_BACKEND"] = "neon"
        os.environ["CODED_PLATFORM"] = "macos-arm64"
        state = module.PublicState()
        require(state.backend() == "NEON", "startup env fallback should remain visible before native frame")
        state.update_frame({
            "backend": "hybrid",
            "scoring_backend": "bpp9000-neon-metal-hybrid",
            "backend_variant": "hybrid-r1-neon-metal-r2-disjoint-nonce",
        })
        require(
            state.backend() == "HYBRID NEON↔METAL",
            f"native Hybrid frame must override stale NEON env, got {state.backend()!r}",
        )
        state.update_frame({"backend": "metal", "scoring_backend": "bpp9000-metal"})
        require(state.backend() == "METAL", "native single-backend frame must remain exact")
    finally:
        os.environ.clear()
        os.environ.update(old)

    runsh = RUNSH.read_text(encoding="utf-8")
    require("M1091V66_MAC_AUTO_REQUEST_AUTHORITY" in runsh, "public runner AUTO authority marker missing")
    require("CODED_PUBLIC_BACKEND_REQUEST_SNAPSHOT" in runsh, "caller request must be frozen before core detection")
    require(
        'backend_raw="${CODED_PUBLIC_BACKEND_REQUEST_SNAPSHOT:-' in runsh,
        "mac Beta helper must use caller request authority",
    )
    require(
        'backend_raw="${CODED_SELECTED_BACKEND:-' not in runsh,
        "execution-state labels must not be backend request authority",
    )

    print("MACOS_PUBLIC_HYBRID_FRAME_AUTHORITY=PASS")
    print("public_default_request=auto")
    print("native_frame_overrides_env=true")
    print("hybrid_display=HYBRID_NEON_METAL")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
