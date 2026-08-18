#!/usr/bin/env bash
# M1091V64_SHARED_RUNSH_V5_AUTOUPDATE_AUTHORITY
# M1091V65_SINGLE_PUBLIC_UPDATE_TRANSITION
# M1091V65_MAC_BETA_PRODUCTIVE_RUNTIME_BRIDGE
#
# One public Linux/macOS lifecycle, one updater.  The proven shared runner is
# pinned and patched with the V5 compatibility adapter before execution.
# No experiment is started here and no second updater/daemon is introduced.

set -Eeuo pipefail

CORE_COMMIT="d8ddc3f38a105233a6327920373a3ebb2939a55f"
CORE_URL="https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/${CORE_COMMIT}/run.sh"
PATCH_URL="${CODED_RUN_V5_PATCH_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/runtime/run-v5-patch.py}"
CONSOLE_URL="${CODED_PUBLIC_CONSOLE_V5_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/runtime/coded-public-console-v5.py}"
CACHE="${TMPDIR:-/tmp}/coded-runsh-v64-${UID:-0}"
CORE="$CACHE/run-core-${CORE_COMMIT}.sh"
PATCHER="$CACHE/run-v5-patch.py"
PATCHED="$CACHE/run-v5.sh"

mkdir -p "$CACHE"

if [ ! -s "$CORE" ]; then
  tmp="$CORE.tmp.$$"
  curl -fsSL --retry 3 --connect-timeout 5 --max-time 30 "$CORE_URL" -o "$tmp"
  grep -Fq 'M1091V51P_FINAL_CHANNEL_AWARE_PUBLIC_AUTOUPDATE' "$tmp"
  mv -f "$tmp" "$CORE"
fi

tmp_patch="$PATCHER.tmp.$$"
curl -fsSL --retry 3 --connect-timeout 5 --max-time 20 "$PATCH_URL?cb=$(date +%s)" -o "$tmp_patch"
grep -Fq 'M1091V64_RUNSH_PATCH_V5' "$tmp_patch"
python3 "$tmp_patch" --self-test >/dev/null
mv -f "$tmp_patch" "$PATCHER"
chmod 0755 "$PATCHER"

tmp_runner="$PATCHED.tmp.$$"
python3 "$PATCHER" \
  --input "$CORE" \
  --output "$tmp_runner" \
  --console-url "$CONSOLE_URL" >/dev/null

# M1091V65: keep the proven updater but normalize its visible restart and repair
# the modern macOS Beta helper. The hardware-tune prestart is sourced only by
# coded-miner-macos; it is never executed as the productive miner itself.
python3 - "$tmp_runner" <<'PYV65'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")


def replace_once(anchor: str, replacement: str, label: str) -> None:
    global text
    count = text.count(anchor)
    if count != 1:
        raise SystemExit(f"M1091V65 {label}: expected exactly one anchor, found {count}")
    text = text.replace(anchor, replacement, 1)


def replace_section(start_marker: str, end_marker: str, replacement: str, label: str) -> None:
    global text
    if text.count(start_marker) != 1 or text.count(end_marker) != 1:
        raise SystemExit(
            f"M1091V65 {label}: boundary mismatch start={text.count(start_marker)} end={text.count(end_marker)}"
        )
    start = text.index(start_marker)
    end = text.index(end_marker, start)
    text = text[:start] + replacement.rstrip() + "\n" + text[end:]


replace_once(
'''coded_m1091v54k_public_restart_loader() {
  coded_ui_loader 75 "Applying update"
}''',
'''# M1091V65_SINGLE_UPDATE_LOADER
coded_m1091v54k_public_restart_loader() {
  if [ "${CODED_PUBLIC_UPDATE_UI_SHOWN:-0}" = "1" ]; then
    return 0
  fi
  export CODED_PUBLIC_UPDATE_UI_SHOWN=1
  coded_ui_loader 100 "Applying update"
  coded_ui_loader_finish
}''',
"restart loader",
)

replace_once(
'''  coded_ui_box '$0.01  IS  CODED'
  coded_ui_loader 12 "Updating CODED MINER"
  sleep 1
  coded_ui_loader 45 "Downloading latest CODED MINER"
  sleep 1
  coded_m1091v54k_public_restart_loader
  sleep 1
  coded_ui_loader 100 "Restarting neural network training"
  coded_ui_loader_finish

  coded_m1091v53a_exec_fresh_runsh''',
'''  # M1091V65_SINGLE_UPDATE_FALLBACK
  coded_m1091v54k_public_restart_loader
  coded_m1091v53a_exec_fresh_runsh''',
"legacy multi-loader fallback",
)

replace_once(
'''coded_public_autoupdate_start

coded_ui_warmup "$CODED_PUBLIC_BOOT_SEC"
coded_ui_loader 100 "Neural network training online"
coded_ui_loader_finish''',
'''coded_public_autoupdate_start

if [ "${CODED_PUBLIC_UPDATE_UI_SHOWN:-0}" = "1" ]; then
  # Fresh runner reached productive startup after an update. Do not render a
  # second progress bar for the same transition; arm the flag for future updates.
  unset CODED_PUBLIC_UPDATE_UI_SHOWN
else
  coded_ui_warmup "$CODED_PUBLIC_BOOT_SEC"
  coded_ui_loader 100 "Neural network training online"
  coded_ui_loader_finish
fi''',
"post-update startup loader",
)

mac_helper = r'''# M1091V65_MAC_BETA_PRODUCTIVE_RUNTIME_BRIDGE
coded_m1091v50y_exec_macos_beta_wrapper_if_present() {
  local root pkg console launcher bin sidecar worker wallet threads pool_url mining_pool
  local run_log analytics_log miner_pid sidecar_pid rc backend_raw backend_arg
  local bridge bridge_tmp bridge_url tail_pid
  local -a args

  root="/tmp/coded-m1091v50h-runsh-beta/pkg"

  worker="${WORKER:-${CODED_WORKER:-coded-worker}}"
  wallet="${WALLET:-${CODED_WALLET:-TEST_WALLET}}"
  threads="${THREADS:-${CODED_THREADS:-}}"
  pool_url="${CODED_POOL_API_URL:-${POOL_API_URL:-http://178.104.150.57:4000}}"
  mining_pool="${POOL:-${CODED_POOL:-pool.codedonqubic.com:7777}}"

  export WORKER="$worker"
  export WALLET="$wallet"
  export CODED_WORKER="$worker"
  export CODED_WORKER_NAME="$worker"
  export CODED_WALLET="$wallet"
  export CODED_POOL_API_URL="$pool_url"
  export POOL_API_URL="$pool_url"
  export CODED_POOL_API_BASE="$pool_url"

  [ -n "$threads" ] && export THREADS="$threads" && export CODED_THREADS="$threads"

  export CODED_ANALYTICS="${CODED_ANALYTICS:-yes}"
  export CODED_FLEET_JOIN="${CODED_FLEET_JOIN:-yes}"
  export CODED_RELEASE_CHANNEL="beta"
  export CODED_RELEASE_COMMIT="${beta_commit:-${CODED_RELEASE_COMMIT:-}}"
  export CODED_RELEASE_VERSION="${beta_version:-${CODED_RELEASE_VERSION:-}}"
  export CODED_MINER_COMMIT="${beta_commit:-${CODED_MINER_COMMIT:-}}"
  export CODED_MINER_VERSION="${beta_version:-${CODED_MINER_VERSION:-}}"
  export GIT_COMMIT="${beta_commit:-${GIT_COMMIT:-}}"
  export RELEASE_VERSION="${beta_version:-${RELEASE_VERSION:-}}"
  export CODED_BUILD_TARGET="macos-arm64"
  export CODED_PLATFORM="macos-arm64"

  backend_raw="${CODED_SELECTED_BACKEND:-${CODED_KERNEL_BACKEND:-${CODED_BACKEND:-${BACKEND:-auto}}}}"
  case "$(printf '%s' "$backend_raw" | tr '[:upper:]' '[:lower:]')" in
    *hybrid*|*neon+metal*) backend_arg="hybrid" ;;
    *metal*) backend_arg="metal" ;;
    *neon*|arm|arm64) backend_arg="neon" ;;
    *) backend_arg="auto" ;;
  esac

  for pkg in \
    "$root/coded-miner" \
    "$root"
  do
    console="$pkg/coded-public-console.py"
    launcher="$pkg/coded-miner-macos"
    bin="$pkg/coded-miner"
    sidecar="$pkg/coded-runtime-sidecar.py"

    if [ -x "$launcher" ] || [ -x "$bin" ]; then
      cd "$pkg" || return 1

      run_log="${TMPDIR:-/tmp}/coded-miner-beta-${worker}.log"
      analytics_log="${TMPDIR:-/tmp}/coded-miner-beta-${worker}-analytics.log"
      : > "$run_log" 2>/dev/null || run_log="/tmp/coded-miner-beta-${worker}.log"
      : > "$run_log" 2>/dev/null || true
      : > "$analytics_log" 2>/dev/null || analytics_log="/tmp/coded-miner-beta-${worker}-analytics.log"
      : > "$analytics_log" 2>/dev/null || true

      coded_m1091v54k_debug "[M1091V65] mac beta package=$pkg requested_backend=$backend_arg worker=$worker"
      coded_m1091v54k_debug "[M1091V65] mac beta log=$run_log analytics_log=$analytics_log"

      if [ -x "$launcher" ]; then
        args=("--backend=$backend_arg" "--pool" "$mining_pool" "--wallet" "$wallet" "--worker" "$worker")
        [ -n "$threads" ] && args+=("--threads" "$threads")
        "$launcher" "${args[@]}" > "$run_log" 2>&1 &
      else
        args=("--pool" "$mining_pool" "--wallet" "$wallet" "--worker" "$worker")
        [ -n "$threads" ] && args+=("--threads" "$threads")
        "$bin" "${args[@]}" > "$run_log" 2>&1 &
      fi
      miner_pid="$!"

      # Current 95450ff packages predate the exact Analytics2 runtime-SHA
      # transport patch. The bridge follows this same PID across launcher exec,
      # resolves the exact final packaged productive binary, hashes its bytes,
      # and only then starts Analytics. No requested-backend hash guessing.
      sidecar_pid=""
      if [ -f "$sidecar" ] && command -v python3 >/dev/null 2>&1; then
        bridge="$pkg/coded-v5-sidecar-bridge.py"
        bridge_tmp="${bridge}.tmp.$$"
        bridge_url="https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/runtime/coded-v5-sidecar-bridge.py"
        if curl -fsSL --retry 3 --connect-timeout 5 --max-time 20 "$bridge_url?cb=$(date +%s)" -o "$bridge_tmp" \
          && grep -Fq 'M1091V65_MAC_BETA_SIDECAR_BUILD_IDENTITY_BRIDGE' "$bridge_tmp"
        then
          mv -f "$bridge_tmp" "$bridge"
          chmod 0755 "$bridge" 2>/dev/null || true
          PYTHONPATH="$pkg${PYTHONPATH:+:$PYTHONPATH}" \
            python3 "$bridge" --sidecar "$sidecar" --package "$pkg" --miner-pid "$miner_pid" \
            >> "$analytics_log" 2>&1 &
          sidecar_pid="$!"
        else
          rm -f "$bridge_tmp" 2>/dev/null || true
          coded_m1091v54k_debug "[M1091V65] exact sidecar bridge unavailable; registry remains fail-closed"
        fi
      fi

      coded_m1091v65_cleanup_mac_beta() {
        [ -z "${sidecar_pid:-}" ] || kill "$sidecar_pid" 2>/dev/null || true
        [ -z "${miner_pid:-}" ] || kill "$miner_pid" 2>/dev/null || true
        [ -z "${sidecar_pid:-}" ] || wait "$sidecar_pid" 2>/dev/null || true
        [ -z "${miner_pid:-}" ] || wait "$miner_pid" 2>/dev/null || true
      }
      trap coded_m1091v65_cleanup_mac_beta HUP INT TERM EXIT

      rc=0
      if [ -f "$console" ] && command -v python3 >/dev/null 2>&1; then
        python3 "$console" "$run_log" "$miner_pid" || rc="$?"
      else
        tail -f "$run_log" &
        tail_pid="$!"
        wait "$miner_pid" || rc="$?"
        kill "$tail_pid" 2>/dev/null || true
        wait "$tail_pid" 2>/dev/null || true
      fi

      coded_m1091v65_cleanup_mac_beta
      trap - HUP INT TERM EXIT
      exit "$rc"
    fi
  done

  return 1
}
'''

replace_section(
    "coded_m1091v50y_exec_macos_beta_wrapper_if_present() {",
    "# M1091V50V_PLATFORM_AWARE_BETA_ASSET",
    mac_helper,
    "mac beta productive helper",
)

path.write_text(text, encoding="utf-8")
PYV65

bash -n "$tmp_runner"
grep -Fq 'M1091V64A_V5_SOURCE_COMMIT_AUTOUPDATE' "$tmp_runner"
grep -Fq 'M1091V64B_PLATFORM_EXACT_BETA_AUTOUPDATE' "$tmp_runner"
grep -Fq 'M1091V64C_NETWORK_ACCEPTED_PUBLIC_CONSOLE_REFRESH' "$tmp_runner"
grep -Fq 'M1091V64D_PLATFORM_EXACT_INITIAL_BETA' "$tmp_runner"
grep -Fq 'M1091V65_SINGLE_UPDATE_LOADER' "$tmp_runner"
grep -Fq 'M1091V65_SINGLE_UPDATE_FALLBACK' "$tmp_runner"
grep -Fq 'M1091V65_MAC_BETA_PRODUCTIVE_RUNTIME_BRIDGE' "$tmp_runner"
grep -Fq 'coded-miner-macos' "$tmp_runner"
grep -Fq -- '--package "$pkg" --miner-pid "$miner_pid"' "$tmp_runner"
! grep -Fq 'launch_entry="$prestart"' "$tmp_runner"
grep -Fq '0c5e9e42c6d86c320af62f4125ca85b2446f2b098893fd6521bcf66c22f7f00a' "$tmp_runner"
! grep -Fq '403e24225f5b0512d0cbf49758fed9a01e7334d3cea565ad6c5e82420b713226' "$tmp_runner"

chmod 0755 "$tmp_runner"
mv -f "$tmp_runner" "$PATCHED"

exec bash "$PATCHED" "$@"
