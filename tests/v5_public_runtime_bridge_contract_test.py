#!/usr/bin/env python3
"""Regression contract for the V5 public console/update/Mac Beta bridge."""

from __future__ import annotations

import calendar
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
CONSOLE = ROOT / "runtime/coded-public-console-v5.py"
BRIDGE = ROOT / "runtime/coded-v5-sidecar-bridge.py"
RUN_SH = ROOT / "run.sh"
COMMIT = "95450ff98bbec20c2952cbd8d5c6e6327280d926"


def load(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    console = load(CONSOLE, "coded_public_console_v5_test")
    original_time = console.time.time
    try:
        fixed = calendar.timegm(time.strptime("2026-08-18 08:00:00", "%Y-%m-%d %H:%M:%S"))
        console.time.time = lambda: fixed
        assert console.epoch_or_fallback("?") == "226"
        assert console.epoch_or_fallback("unknown") == "226"
        assert console.epoch_or_fallback("226") == "226"
    finally:
        console.time.time = original_time

    bridge = load(BRIDGE, "coded_v5_sidecar_bridge_test")
    with tempfile.TemporaryDirectory() as tmp:
        package = Path(tmp)
        binary = package / "coded-miner-neon"
        binary.write_bytes(b"coded-v5-macos-neon-runtime\n")
        binary.chmod(0o755)
        expected = hashlib.sha256(binary.read_bytes()).hexdigest()
        (package / "release_manifest.json").write_text(
            json.dumps({"source_commit": COMMIT, "commit": COMMIT}),
            encoding="utf-8",
        )

        original_command = bridge.process_command
        original_alive = bridge.pid_alive
        try:
            bridge.process_command = lambda pid: f"{binary} --worker Test4"
            bridge.pid_alive = lambda pid: True
            resolved = bridge.resolve_productive_binary(package, 1234, 1)
        finally:
            bridge.process_command = original_command
            bridge.pid_alive = original_alive

        assert resolved is not None
        selected, backend = resolved
        assert selected == binary.resolve()
        assert backend == "neon"
        assert bridge.sha256_file(selected) == expected
        assert bridge.full_commit(package) == COMMIT

        payload = {"raw": {"analytics_frame": {"algorithm": "bpp9000"}}}
        bridge.patch_dict(payload, commit=COMMIT, digest=expected)
        frame = payload["raw"]["analytics_frame"]
        assert frame["binary_sha256"] == expected
        assert frame["source_commit"] == COMMIT

    run_text = RUN_SH.read_text(encoding="utf-8")
    assert "M1091V65_SINGLE_UPDATE_LOADER" in run_text
    assert "M1091V65_SINGLE_UPDATE_FALLBACK" in run_text
    assert "M1091V65_MAC_BETA_PRODUCTIVE_RUNTIME_BRIDGE" in run_text
    assert "coded-miner-macos" in run_text
    assert '--package "$pkg" --miner-pid "$miner_pid"' in run_text
    assert 'launch_entry="$prestart"' not in run_text
    assert 'coded_ui_loader 100 "Applying update"' in run_text

    subprocess.run(["bash", "-n", str(RUN_SH)], check=True)
    print("v5_public_runtime_bridge_contract=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
