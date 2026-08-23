#!/usr/bin/env python3
"""Regression contract for V5 public runtime policy + console bridge."""

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
RUN_PS1 = ROOT / "run.ps1"
COMMIT = "95450ff98bbec20c2952cbd8d5c6e6327280d926"
POLICY_MARKER = "M1091V70_RUNTIME_POLICY_AUTHORITY_V1"
PINNED_PUBLIC_RUNNER = "5e898b60779ea163b07bb44dd7a3e1186b414f8b"


def load(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def shell_python_blocks(text: str):
    """Yield exact Python heredocs used by the V70 wrapper."""
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        marker = None
        for candidate in ("PY", "PYQ"):
            if f"<<'{candidate}'" in line:
                marker = candidate
                break
        if marker is None:
            i += 1
            continue
        block = []
        i += 1
        while i < len(lines) and lines[i] != marker:
            block.append(lines[i])
            i += 1
        assert i < len(lines), f"unterminated heredoc {marker}"
        yield "\n".join(block) + "\n"
        i += 1


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
    ps_text = RUN_PS1.read_text(encoding="utf-8")

    # Linux + macOS: desired policy must be resolved before delegating into the
    # proven runner where Hardware Tune / execution selection occurs.
    assert POLICY_MARKER in run_text
    assert PINNED_PUBLIC_RUNNER in run_text
    assert "/analytics2/runtime-policy" in run_text
    assert 'export CODED_HARDWARE_TUNE_REQUESTED_BACKEND="$backend"' in run_text
    assert 'export CODED_PUBLIC_BACKEND_REQUEST_SNAPSHOT="$backend"' in run_text
    assert 'export BACKEND="$backend"' in run_text
    assert 'CODED_RUNTIME_POLICY_AUTHORITY="miner_default_profiles"' in run_text
    assert 'managed CODED runtime policy is inconsistent' in run_text
    assert 'CODED_RUNTIME_POLICY_CACHE_DIR' in run_text
    assert '--backend=*' in run_text and '-avx512' in run_text and '-avx2' in run_text
    assert 'export CODED_KERNEL_BACKEND="$backend"' not in run_text
    assert 'export CODED_SELECTED_BACKEND="$backend"' not in run_text
    assert 'exec bash "$coded_v70_base" "$@"' in run_text

    blocks = list(shell_python_blocks(run_text))
    assert len(blocks) >= 3
    for idx, block in enumerate(blocks):
        compile(block, f"run.sh:python-heredoc-{idx}", "exec")

    # Windows: same authority before the old AUTO detector. The wrapper sets
    # request inputs only and blocks backend shorthand from overwriting policy.
    assert POLICY_MARKER in ps_text
    assert PINNED_PUBLIC_RUNNER in ps_text
    assert "/analytics2/runtime-policy" in ps_text
    assert '$env:CODED_HARDWARE_TUNE_REQUESTED_BACKEND = $policyBackend' in ps_text
    assert '$env:CODED_PUBLIC_BACKEND_REQUEST_SNAPSHOT = $policyBackend' in ps_text
    assert '$env:BACKEND = $policyBackend' in ps_text
    assert '$env:CODED_RUNTIME_POLICY_AUTHORITY = "miner_default_profiles"' in ps_text
    assert 'refusing AUTO/backend fallback' in ps_text
    assert 'CODED\\runtime-policy' in ps_text
    assert "'^--?backend='" in ps_text
    assert '$env:CODED_KERNEL_BACKEND = $policyBackend' not in ps_text
    assert '$env:CODED_SELECTED_BACKEND = $policyBackend' not in ps_text
    assert '& $delegate @params' in ps_text

    subprocess.run(["bash", "-n", str(RUN_SH)], check=True)
    print("v5_public_runtime_policy_bridge_contract=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
