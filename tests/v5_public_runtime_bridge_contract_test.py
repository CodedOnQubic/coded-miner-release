#!/usr/bin/env python3
"""Regression contract for the V5 public console/update/Mac Beta bridge."""

from __future__ import annotations

import calendar
import hashlib
import importlib.util
import json
import os
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

    # AUTO is only a request on Apple Silicon. The productive Hybrid handoff and
    # then native frame identity must win over it in the public console.
    original_env = dict(os.environ)
    try:
        os.environ["CODED_SELECTED_BACKEND"] = "auto"
        os.environ["CODED_PLATFORM"] = "macos-arm64"
        state = console.PublicState()
        assert state.backend() == "AUTO→HYBRID (NEON+METAL)"
        state.update_line(
            "CODED_MACOS_LAUNCHER=PASS requested_backend=auto "
            "effective_backend=hybrid hybrid_component_backends=neon,metal"
        )
        assert state.backend() == "HYBRID (NEON+METAL)"
        state.update_line(
            "[CODED_ANALYTICS_FRAME] backend=hybrid "
            "active_backends=neon,metal"
        )
        assert state.backend() == "HYBRID (NEON+METAL)"

        explicit = console.PublicState()
        explicit.requested_backend = "neon"
        explicit.effective_backend = "neon"
        explicit.frame_backend = ""
        assert explicit.backend() == "NEON"
        explicit.requested_backend = "metal"
        explicit.effective_backend = "metal"
        assert explicit.backend() == "METAL"
    finally:
        os.environ.clear()
        os.environ.update(original_env)

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

    # Public Mac one-liner and Analytics2 must share the exact same worker-bound
    # miner log. This is the regression that made running Macs remain OFFLINE.
    original_env = dict(os.environ)
    try:
        os.environ.pop("RUN_LOG", None)
        os.environ.pop("CODED_RUN_LOG", None)
        os.environ.pop("CODED_ANALYTICS_LOG", None)
        os.environ["TMPDIR"] = "/tmp"
        os.environ["CODED_WORKER_NAME"] = "maco"
        log_path = bridge.resolve_miner_log("")
        assert str(log_path) == "/tmp/coded-miner-beta-maco.log"
        bridge.bind_public_runtime_identity(log_path)
        assert os.environ["RUN_LOG"] == str(log_path)
        assert os.environ["CODED_RUN_LOG"] == str(log_path)
        assert os.environ["CODED_ANALYTICS_LOG"] == str(log_path)
        assert os.environ["CODED_RIG_ID"] == "maco"

        bridge.bind_backend_identity("hybrid")
        assert os.environ["CODED_BACKEND"] == "hybrid"
        assert os.environ["CODED_SELECTED_BACKEND"] == "hybrid"
        assert os.environ["CODED_KERNEL_BACKEND"] == "hybrid"
        assert os.environ["CODED_HYBRID_CPU_BACKEND"] == "neon"
        assert os.environ["CODED_HYBRID_GPU_BACKEND"] == "metal"
        assert os.environ["CODED_HYBRID_COMPONENT_BACKENDS"] == "neon,metal"
    finally:
        os.environ.clear()
        os.environ.update(original_env)

    run_text = RUN_SH.read_text(encoding="utf-8")
    assert "M1091V65_SINGLE_UPDATE_LOADER" in run_text
    assert "M1091V65_SINGLE_UPDATE_FALLBACK" in run_text
    assert "M1091V65_MAC_BETA_PRODUCTIVE_RUNTIME_BRIDGE" in run_text
    assert "coded-miner-macos" in run_text
    assert '--package "$pkg" --miner-pid "$miner_pid"' in run_text
    # The obsolete assignment is present exactly once only as a negative grep
    # guard against generated-runner regression; it is not executable code.
    assert run_text.count('launch_entry="$prestart"') == 1
    assert '! grep -Fq \'launch_entry="$prestart"\'' in run_text
    assert 'coded_ui_loader 100 "Applying update"' in run_text

    subprocess.run([sys.executable, "-m", "py_compile", str(CONSOLE), str(BRIDGE)], check=True)
    subprocess.run(["bash", "-n", str(RUN_SH)], check=True)
    print("v5_public_runtime_bridge_contract=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
