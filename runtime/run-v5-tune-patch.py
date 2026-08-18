#!/usr/bin/env python3
"""Replace the legacy macOS Beta Hardware Tune V2 runner block with Tune V5.

The public runner remains the single lifecycle/updater authority. This patch only
changes the macOS Beta prestart bridge so the packaged V5 controller is sourced
before productive BPP9000 activation. Hardware Tune remains local runtime
selection authority and never consumes NETWORK_ACCEPTED.
"""
from __future__ import annotations

import argparse
from pathlib import Path

MARKER = "M1091V65A_MACOS_V5_LOCAL_TUNE_RUNNER_BRIDGE"
OLD_MARKER = "# M1091V55H_MAC_BETA_RUNNER_INTEGRATED_HARDWARE_TUNE"
NEXT_MARKER = "# M1091P055_MACOS_BETA_BPP9000_RUNTIME_AUTHORITY"

NEW_BLOCK = r'''# M1091V65A_MACOS_V5_LOCAL_TUNE_RUNNER_BRIDGE
#
# The packaged Anthill V5 Beta owns Hardware Tune. Source its prestart exactly
# once per public-runner lifecycle before BPP9000 activation, then hand the
# selected productive binary/threads back to the existing runner. Tune is
# local hardware/runtime authority only; NETWORK_ACCEPTED is not consulted.
coded_m1091v55h_run_macos_beta_hardware_tune() {
  local manifest=""
  local prestart=""
  local task=""
  local requested=""
  local selected_threads=""
  local selected_backend=""

  [ "$PLATFORM" = "macos-arm64" ] || return 0
  [ "${CODED_RELEASE_CHANNEL:-latest}" = "beta" ] || return 0

  manifest="$INSTALL_DIR/release_manifest.json"
  prestart="$INSTALL_DIR/coded-hardware-tune-prestart.sh"
  task="$INSTALL_DIR/task_bpp9000.bin"

  # Fail open to the already selected productive binary if a malformed/old
  # package somehow reaches this V5 runner. The package publisher separately
  # fail-closes V5 asset completeness before publication.
  for required in \
    "$manifest" \
    "$prestart" \
    "$task" \
    "$INSTALL_DIR/hardware_tune_v5/startup.py" \
    "$INSTALL_DIR/hardware_tune_v5/policy.py" \
    "$INSTALL_DIR/hardware_tune_v5/capabilities.py"
  do
    if [ ! -f "$required" ]; then
      coded_m1091v54k_debug \
        "[M1091V65A] hardware_tune_v5=fallback reason=package_asset_missing path=$required"
      return 0
    fi
  done

  if [ ! -x "$prestart" ]; then
    coded_m1091v54k_debug \
      "[M1091V65A] hardware_tune_v5=fallback reason=prestart_not_executable"
    return 0
  fi

  # Normalize historical public-runner labels into the V5 lane vocabulary.
  requested="${CODED_HARDWARE_TUNE_REQUESTED_BACKEND:-${BACKEND:-auto}}"
  case "$requested" in
    hybrid|neon+metal) requested="neon+metal" ;;
    neon|metal|auto) ;;
    *) requested="auto" ;;
  esac

  export CODED_PACKAGE_DIR="$INSTALL_DIR"
  export CODED_HARDWARE_TUNE_STATE_DIR="${CODED_HARDWARE_TUNE_STATE_DIR:-$HOME/.coded/hardware-tune-v5}"
  export CODED_HARDWARE_TUNE_MAX_THREADS="${CODED_HARDWARE_TUNE_MAX_THREADS:-$THREADS}"
  export CODED_HARDWARE_TUNE_REQUESTED_BACKEND="$requested"
  export CODED_WORKER_NAME="$WORKER_SAFE"
  export CODED_RIG_ID="$WORKER_SAFE"
  export CODED_POOL_API_URL="$API_ROOT"
  export POOL_API_URL="$API_ROOT"

  # run.sh restarts use exec and therefore retain exported environment. Clear
  # the process-lifetime guard before the one intended V5 prestart invocation
  # in this new runner lifecycle so exact-profile reuse can execute and report.
  unset CODED_HARDWARE_TUNE_V5_EXECUTED

  coded_ui_loader 62 "Tuning Apple Silicon runtime"

  SCRIPT_DIR="$INSTALL_DIR"
  # shellcheck disable=SC1090
  . "$prestart"

  if [ "${CODED_HARDWARE_TUNE_STATUS:-}" != "tuned" ] ||
     [ -z "${MINER_BIN:-}" ] ||
     [ ! -x "${MINER_BIN:-}" ]
  then
    coded_m1091v54k_debug \
      "[M1091V65A] hardware_tune_v5=fallback status=${CODED_HARDWARE_TUNE_STATUS:-missing} error=${CODED_HARDWARE_TUNE_ERROR:-none} keep_threads=$THREADS"
    coded_ui_loader 68 "Hardware tuning fallback"
    return 0
  fi

  selected_threads="${CODED_HARDWARE_TUNE_THREADS:-}"
  case "$selected_threads" in
    ''|*[!0-9]*|0) selected_threads="$THREADS" ;;
  esac

  selected_backend="${CODED_HARDWARE_TUNE_BACKEND:-}"
  case "$selected_backend" in
    neon)
      BACKEND="neon"
      SELECTED_BACKEND="neon"
      ;;
    metal)
      BACKEND="metal"
      SELECTED_BACKEND="metal"
      ;;
    neon+metal|hybrid)
      BACKEND="hybrid"
      SELECTED_BACKEND="hybrid"
      ;;
    *)
      coded_m1091v54k_debug \
        "[M1091V65A] hardware_tune_v5=fallback reason=unsupported_selected_backend backend=${selected_backend:-missing}"
      coded_ui_loader 68 "Hardware tuning fallback"
      return 0
      ;;
  esac

  THREADS="$selected_threads"
  CODED_THREADS="$selected_threads"
  MINER_EXE="$MINER_BIN"

  export THREADS CODED_THREADS BACKEND MINER_EXE
  export CODED_BACKEND="$SELECTED_BACKEND"
  export CODED_KERNEL_BACKEND="$SELECTED_BACKEND"
  export CODED_SELECTED_BACKEND="$SELECTED_BACKEND"

  coded_m1091v54k_debug \
    "[M1091V65A] hardware_tune_v5=applied authority=coded.hardware_tune.local_runtime.v5 backend=$SELECTED_BACKEND threads=$THREADS reused=${CODED_HARDWARE_TUNE_REUSED:-0}"
  coded_ui_loader 68 "Hardware tuning complete"
  return 0
}

'''


def transform(text: str) -> str:
    if MARKER in text:
        return text
    start = text.find(OLD_MARKER)
    end = text.find(NEXT_MARKER)
    if start < 0 or end < 0 or end <= start:
        raise RuntimeError("legacy macOS Tune block boundary unavailable")
    out = text[:start] + NEW_BLOCK + text[end:]

    required = (
        MARKER,
        "hardware_tune_v5/startup.py",
        "hardware_tune_v5/policy.py",
        "hardware_tune_v5/capabilities.py",
        'unset CODED_HARDWARE_TUNE_V5_EXECUTED',
        '. "$prestart"',
        'MINER_EXE="$MINER_BIN"',
        'authority=coded.hardware_tune.local_runtime.v5',
    )
    for token in required:
        if token not in out:
            raise RuntimeError("V5 macOS Tune bridge token missing: " + token)

    old_forbidden = (
        "hardware_tune/probe_adapter.py",
        "python3 -m hardware_tune.cli",
        "CODED_HARDWARE_TUNE_FAILURE_TTL_SECONDS",
    )
    for token in old_forbidden:
        if token in out:
            raise RuntimeError("legacy macOS Tune V2 dependency survived: " + token)
    return out


def self_test() -> None:
    fixture = '''#!/usr/bin/env bash
# M1091V55H_MAC_BETA_RUNNER_INTEGRATED_HARDWARE_TUNE
coded_m1091v55h_run_macos_beta_hardware_tune() {
  probe="$INSTALL_DIR/hardware_tune/probe_adapter.py"
  python3 -m hardware_tune.cli --probe "python3 $probe"
  CODED_HARDWARE_TUNE_FAILURE_TTL_SECONDS=300
}

# M1091P055_MACOS_BETA_BPP9000_RUNTIME_AUTHORITY
coded_m1091p055_activate_macos_beta_bpp9000() { :; }
'''
    out = transform(fixture)
    assert MARKER in out
    assert 'hardware_tune_v5/startup.py' in out
    assert '. "$prestart"' in out
    assert 'unset CODED_HARDWARE_TUNE_V5_EXECUTED' in out
    assert 'MINER_EXE="$MINER_BIN"' in out
    assert "hardware_tune/probe_adapter.py" not in out
    assert "python3 -m hardware_tune.cli" not in out
    assert "NETWORK_ACCEPTED is not consulted" in out
    print("macos_v5_local_tune_runner_bridge=PASS")
    print("legacy_macos_tune_v2_dependency=ABSENT")
    print("FINAL=PASS_RUN_V5_TUNE_PATCH_SELF_TEST")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input")
    parser.add_argument("--output")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0
    if not args.input or not args.output:
        parser.error("--input and --output are required unless --self-test is used")
    source = Path(args.input).read_text(encoding="utf-8")
    Path(args.output).write_text(transform(source), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
