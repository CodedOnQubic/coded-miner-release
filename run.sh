#!/usr/bin/env bash
# M1091V51U_FORCE_RAW_MAIN_REFRESH_AFTER_V51T
# M1091V51N_FINAL_SAFE_PUBLIC_BETA_AUTOUPDATE_COMPAT
# M1091V51P_FINAL_CHANNEL_AWARE_PUBLIC_AUTOUPDATE
# M1091V51Q_PUBLIC_AUTOUPDATE_SINGLE_LOOP_CLEANUP

# M1091V53A_CHANNEL_SAFE_PUBLIC_RESTART
# M1091V54B_PUBLIC_RUNNER_RESTART_AND_MAC_ARM_NEON_LABEL
# M1091V54K_PUBLIC_COSMETIC_AUTOUPDATE_TRANSITION
# M1091V55B_PARENT_OWNED_QUIET_PUBLIC_RESTART
# M1091V55E_PUBLIC_STDERR_FILTER_AND_CONSOLE_STOP
coded_m1091v55e_install_public_stderr_filter() {
  # Hide only Bash job-control termination noise from killed public child jobs.
  # Real errors remain visible. Set CODED_PUBLIC_DEBUG=1 to disable filtering.
  if [ "${CODED_PUBLIC_DEBUG:-0}" = "1" ]; then
    return 0
  fi
  if [ -n "${CODED_V55E_STDERR_FILTERED:-}" ]; then
    return 0
  fi
  export CODED_V55E_STDERR_FILTERED=1
  exec 3>&2
  exec 2> >(exec awk '
    /Terminated: 15/ && /CODED_|coded-runtime-sidecar|coded-miner|MINER_EXE/ { next }
    { print > "/dev/fd/3"; fflush("/dev/fd/3") }
  ')

  # M1091V55F/R2: process substitution is now a direct awk
  # child owned by this runner. Export the PID because channel-safe
  # restarts use exec and must retain ownership of the same filter.
  CODED_V55E_STDERR_FILTER_PID="$!"
  export CODED_V55E_STDERR_FILTER_PID
}

coded_m1091v55e_stop_console_quiet() {
  if [ -n "${CONSOLE_PID:-}" ] && kill -0 "$CONSOLE_PID" 2>/dev/null; then
    kill "$CONSOLE_PID" 2>/dev/null || true
    wait "$CONSOLE_PID" 2>/dev/null || true
  fi
}

coded_m1091v55e_install_public_stderr_filter
# Public default: keep update transitions clean. Set CODED_PUBLIC_DEBUG=1 for dev logs.
CODED_PUBLIC_DEBUG="${CODED_PUBLIC_DEBUG:-0}"
set +m 2>/dev/null || true
set +b 2>/dev/null || true
coded_m1091v54k_debug() {
  if [ "${CODED_PUBLIC_DEBUG:-0}" = "1" ]; then
    printf '%s\n' "$*"
  fi
}
coded_m1091v54k_public_restart_loader() {
  coded_ui_loader 75 "Applying update"
}
coded_m1091v53a_preserve_restart_env() {
  export WALLET="${WALLET:-${CODED_WALLET:-}}"
  export WORKER="${WORKER_SAFE:-${WORKER:-${CODED_WORKER:-${CODED_WORKER_NAME:-}}}}"
  export BACKEND="${BACKEND:-${CODED_BACKEND:-auto}}"

  # M1091V54B: macOS ARM must continue on the NEON path across autoupdate.
  # Older runs may have exported CODED_BACKEND=scalar because the binary name
  # contained "scalar"; do not let that stale label poison the restart.
  case "$(uname -s 2>/dev/null):$(uname -m 2>/dev/null)" in
    Darwin:arm64|Darwin:aarch64)
      case "$BACKEND" in
        ""|auto|AUTO|scalar|SCALAR|ARM|arm)
          BACKEND="arm-neon"
          ;;
      esac
      export CODED_PLATFORM="macos-arm64"
      export CODED_BACKEND="arm-neon"
      export CODED_KERNEL_BACKEND="arm-neon"
      export CODED_ARM_NEON_KERNEL="${CODED_ARM_NEON_KERNEL:-compat32}"
      ;;
  esac

  export THREADS="${THREADS:-${CODED_THREADS:-0}}"
  export POOL="${POOL:-${CODED_POOL:-pool.codedonqubic.com:7777}}"
  export API_ROOT="${API_ROOT:-${CODED_POOL_API_BASE:-https://api.codedonqubic.com}}"

  export CODED_WALLET="$WALLET"
  export CODED_WORKER="$WORKER"
  export CODED_WORKER_NAME="$WORKER"
  export CODED_RIG_ID="$WORKER"
  export CODED_BACKEND="$BACKEND"
  export CODED_THREADS="$THREADS"
  export CODED_POOL="$POOL"
  export CODED_POOL_API_BASE="$API_ROOT"
  export CODED_PUBLIC_UPDATE_SEC="${CODED_PUBLIC_UPDATE_SEC:-60}"
  export CODED_PUBLIC_BRAND_EVERY="${CODED_PUBLIC_BRAND_EVERY:-9}"
  export CODED_PUBLIC_LINE_SEC="${CODED_PUBLIC_LINE_SEC:-1}"
  export CODED_PUBLIC_BOOT_STATUS="${CODED_PUBLIC_BOOT_STATUS:-Updating CODED MINER}"
  export CODED_PUBLIC_BOOT_SEC="${CODED_PUBLIC_BOOT_SEC:-10}"

  # Next run.sh must recompute beta/latest from channel-status.
  # This prevents stale beta URLs after Push Beta to Public disables beta.
  unset CODED_RELEASE_DOWNLOAD_URL CODED_RELEASE_ASSET_NAME CODED_BETA_SELECTED_NORMAL_FLOW

  if coded_m1091v50h_beta_requested; then
    export CODED_BETA_REQUESTED="1"
    export CODED_BETA="yes"
    export BETA="yes"
  else
    export CODED_BETA_REQUESTED="0"
    unset CODED_BETA BETA
  fi
}

coded_m1091v53a_exec_fresh_runsh() {
  coded_m1091v53a_preserve_restart_env
  if coded_m1091v50h_beta_requested; then
    exec bash -c "$(curl -fsSL --retry 3 "${CODED_PUBLIC_RUNSH_URL}?cb=$(date +%s)")" -- -beta
  fi
  exec bash -c "$(curl -fsSL --retry 3 "${CODED_PUBLIC_RUNSH_URL}?cb=$(date +%s)")"
}

# M1091V51R_EXEC_RESTART_REQUIRED_AFTER_AUTOUPDATE
# M1091V51S_PARENT_SIGNAL_RESTART_WATCHER
# M1091V51T_RESTART_WATCHER_CALL_AFTER_DEFINITION
# M1091V51C_BETA_AS_EFFECTIVE_RELEASE_NORMAL_PUBLIC_FLOW
coded_m1091v51c_effective_download_url() {
  local default_url
  default_url="$1"
  if [ -n "${CODED_RELEASE_DOWNLOAD_URL:-}" ]; then
    printf '%s\n' "$CODED_RELEASE_DOWNLOAD_URL"
  else
    printf '%s\n' "$default_url"
  fi
}

coded_m1091v51c_print_effective_status() {
  if [ "${CODED_RELEASE_CHANNEL:-latest}" = "beta" ]; then
    coded_m1091v54k_debug "Status: beta | release_channel=beta | commit=${CODED_RELEASE_COMMIT:-unknown} | version=${CODED_RELEASE_VERSION:-unknown}"
  else
    coded_m1091v54k_debug "Status: latest | release_channel=latest"
  fi
}
# M1091V51B_MACOS_BETA_PUBLIC_CONSOLE_FLOW
coded_m1091v50y_exec_macos_beta_wrapper_if_present() {
  local root pkg console bin worker wallet threads pool_url run_log miner_pid

  root="/tmp/coded-m1091v50h-runsh-beta/pkg"

  worker="${WORKER:-${CODED_WORKER:-coded-worker}}"
  wallet="${WALLET:-${CODED_WALLET:-TEST_WALLET}}"
  threads="${THREADS:-${CODED_THREADS:-}}"
  pool_url="${CODED_POOL_API_URL:-${POOL_API_URL:-http://178.104.150.57:4000}}"

  export WORKER="$worker"
  export WALLET="$wallet"
  export CODED_WORKER="$worker"
  export CODED_WALLET="$wallet"
  export CODED_POOL_API_URL="$pool_url"
  export POOL_API_URL="$pool_url"

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

  for pkg in \
    "$root/coded-miner" \
    "$root"
  do
    console="$pkg/coded-public-console.py"
    bin="$pkg/coded-miner"

    if [ -x "$bin" ]; then
      cd "$pkg" || return 1

      run_log="${TMPDIR:-/tmp}/coded-miner-beta-${worker}.log"
      : > "$run_log" 2>/dev/null || run_log="/tmp/coded-miner-beta-${worker}.log"
      : > "$run_log" 2>/dev/null || true

      coded_m1091v54k_debug "[M1091V51B] starting macOS beta public console flow worker=$worker commit=${CODED_RELEASE_COMMIT:-unknown}"
      coded_m1091v54k_debug "[M1091V51B] beta bin=$bin"
      coded_m1091v54k_debug "[M1091V51B] beta log=$run_log"

      "$bin" > "$run_log" 2>&1 &
      miner_pid="$!"

      if [ -f "$console" ] && command -v python3 >/dev/null 2>&1; then
        exec python3 "$console" "$run_log" "$miner_pid"
      fi

      coded_m1091v54k_debug "[M1091V51B] console missing; tailing beta miner log"
      exec tail -f "$run_log"
    fi
  done

  return 1
}
# M1091V50V_PLATFORM_AWARE_BETA_ASSET
coded_m1091v50v_beta_asset_name() {
  local os arch
  os="$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m 2>/dev/null | tr '[:upper:]' '[:lower:]')"

  case "${os}:${arch}" in
    darwin:arm64|darwin:aarch64)
      printf '%s\n' "coded-miner-macos-arm64-beta-latest.tar.gz"
      ;;
    *)
      printf '%s\n' "${beta_asset_name:-coded-miner-beta-latest.tar.gz}"
      ;;
  esac
}

coded_m1091v50v_exec_macos_beta_binary_if_present() {
  local root entry
  root="/tmp/coded-m1091v50h-runsh-beta/pkg"

  for entry in \
    "$root/coded-miner/coded-miner" \
    "$root/coded-miner" \
    "$root/pkg/coded-miner/coded-miner"
  do
    if [ -x "$entry" ]; then
      coded_m1091v54k_debug "[M1091V50V] starting macOS beta binary entry=$entry"
      exec "$entry"
    fi
  done

  entry="$(find "$root" -maxdepth 4 -type f -name coded-miner -perm -111 2>/dev/null | head -1 || true)"
  if [ -n "$entry" ] && [ -x "$entry" ]; then
    coded_m1091v54k_debug "[M1091V50V] starting discovered macOS beta binary entry=$entry"
    exec "$entry"
  fi

  return 1
}
# M1091V50H_RUN_SH_BETA_BOOTSTRAP_VERSION_TAG
# Public run.sh beta bootstrap:
# - default path remains unchanged
# - beta activates only via --beta/-beta, BETA=yes, CODED_BETA=yes, CODED_RELEASE_CHANNEL=beta, or config containing beta=yes
# - beta asset is downloaded from active beta.version tag, never from GitHub releases/latest
# - if beta fails, falls back to original public/latest run.sh below
coded_m1091v50h_beta_requested() {
  # M1091V53A_CHANNEL_SAFE_PUBLIC_RESTART
  # Supports CLI beta flags, restart-preserved beta intent,
  # env beta flags, and Hive/jsonish extra config such as {"beta":"yes"}.
  case " ${0:-} $* " in
    *" --beta "*|*" -beta "*) return 0 ;;
  esac

  local v
  for v in \
    "${CODED_BETA_REQUESTED:-}" \
    "${BETA:-}" \
    "${CODED_BETA:-}" \
    "${CODED_RELEASE_CHANNEL:-}"
  do
    case "$v" in
      1|yes|YES|true|TRUE|beta|BETA) return 0 ;;
    esac
  done

  for v in \
    "${CUSTOM_CONFIG:-}" \
    "${CUSTOM_USER_CONFIG:-}" \
    "${HIVE_CUSTOM_CONFIG:-}" \
    "${USER_CONFIG:-}" \
    "${MINER_CUSTOM_CONFIG:-}" \
    "${CODED_USER_CONFIG:-}" \
    "${EXTRA_CONFIG:-}"
  do
    printf '%s
' "$v" | grep -Eiq '"?beta"?[[:space:]]*[:=][[:space:]]*"?((yes)|(true)|(1))"?' && return 0
  done

  return 1
}

coded_m1091v50h_json_field() {
  file="$1"
  key="$2"

  [ -f "$file" ] || return 0

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" "$key" <<'PYJSON'
import json, sys
path = sys.argv[1]
key = sys.argv[2]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    sys.exit(0)

cur = data
for part in key.split("."):
    if not isinstance(cur, dict):
        sys.exit(0)
    cur = cur.get(part)

if cur is None:
    sys.exit(0)

if isinstance(cur, bool):
    print("true" if cur else "false")
else:
    print(cur)
PYJSON
  else
    grep -E "\"${key##*.}\"[[:space:]]*:" "$file" | head -1 | sed -E 's/.*:[[:space:]]*"?([^",}]+)"?.*/\1/'
  fi
}


# M1091V50J_RUN_SH_STATUS_ONLY_NO_PAYLOAD_PATCH
coded_m1091v50h_try_beta() {
  [ "${CODED_BETA_BOOTSTRAP_ACTIVE:-}" = "1" ] && return 1
  coded_m1091v50h_beta_requested "$@" || return 1


beta_asset_name="$(coded_m1091v50v_beta_asset_name)"
coded_m1091v54k_debug "[M1091V50V] beta asset=$beta_asset_name"
  coded_m1091v54k_debug "[M1091V50H] beta requested in public run.sh"

  pool="${CODED_POOL_API_URL:-${POOL_API_URL:-http://178.104.150.57:4000}}"
  channel_url="${CODED_RELEASE_CHANNEL_STATUS_URL:-${pool%/}/admin/release/channel-status}"

  tmp_root="${CODED_BETA_TMP_ROOT:-/tmp/coded-m1091v50h-runsh-beta}"
  rm -rf "$tmp_root"
  mkdir -p "$tmp_root"

  status_json="$tmp_root/channel-status.json"

  if ! curl -fsSL --max-time 15 "$channel_url" -o "$status_json"; then
    coded_m1091v54k_debug "[M1091V50H] beta channel-status unavailable; falling back to public latest"
    return 1
  fi

  beta_version="$(coded_m1091v50h_json_field "$status_json" beta.version || true)"
  beta_commit="$(coded_m1091v50h_json_field "$status_json" beta.commit || true)"
  beta_asset_ok="$(coded_m1091v50h_json_field "$status_json" beta.assets.linux.ok || true)"

  if [ -z "$beta_version" ] || [ "$beta_version" = "null" ]; then
    coded_m1091v54k_debug "[M1091V50H] no active beta version; falling back to public latest"
    return 1
  fi

  if [ "$beta_asset_ok" = "false" ]; then
    coded_m1091v54k_debug "[M1091V50H] beta linux asset not ok; falling back to public latest"
    return 1
  fi

  beta_url="https://github.com/CodedOnQubic/coded-miner-release/releases/download/${beta_version}/${beta_asset_name:-coded-miner-beta-latest.tar.gz}"

  export CODED_RELEASE_CHANNEL="beta"
  export CODED_RELEASE_COMMIT="$beta_commit"
  export CODED_RELEASE_VERSION="$beta_version"
  export CODED_MINER_COMMIT="$beta_commit"
  export CODED_MINER_VERSION="$beta_version"
  export GIT_COMMIT="$beta_commit"
  export RELEASE_VERSION="$beta_version"
  export CODED_RELEASE_ASSET_NAME="${beta_asset_name:-coded-miner-beta-latest.tar.gz}"
  export CODED_RELEASE_DOWNLOAD_URL="$beta_url"
  export CODED_BETA_SELECTED_NORMAL_FLOW="1"

  coded_m1091v54k_debug "[M1091V51C] beta selected as effective release"
  coded_m1091v54k_debug "[M1091V51C] beta asset=${CODED_RELEASE_ASSET_NAME}"
  coded_m1091v54k_debug "[M1091V51C] beta url=${CODED_RELEASE_DOWNLOAD_URL}"
  coded_m1091v54k_debug "[M1091V51C] continuing through normal public runner autoupdate/log flow"
  coded_m1091v54k_debug "Status: beta | release_channel=beta | commit=${CODED_RELEASE_COMMIT} | version=${CODED_RELEASE_VERSION}"

  # Return non-zero intentionally: caller uses `try_beta || true`,
  # so normal public runner continues with CODED_RELEASE_DOWNLOAD_URL override.
  return 1
}

# M1091V50I2_RUN_SH_STATUS_WRAPPER
# M1091V51N_FINAL_SAFE_PUBLIC_BETA_AUTOUPDATE_COMPAT
if coded_m1091v50h_beta_requested "$@"; then
  export CODED_BETA_REQUESTED="1"
  export CODED_BETA="${CODED_BETA:-yes}"
  coded_m1091v50h_try_beta "$@" || {
    if [ "${CODED_BETA_SELECTED_NORMAL_FLOW:-0}" = "1" ]; then
      export CODED_RELEASE_STATUS="beta"
      export CODED_RELEASE_CHANNEL="beta"
      coded_m1091v51c_print_effective_status
    else
      export CODED_RELEASE_STATUS="latest"
      export CODED_RELEASE_CHANNEL="latest"
      unset CODED_RELEASE_DOWNLOAD_URL CODED_RELEASE_ASSET_NAME CODED_BETA_SELECTED_NORMAL_FLOW
      coded_m1091v54k_debug "Status: latest | release_channel=latest | beta_fallback=1"
    fi
  }
else
  export CODED_BETA_REQUESTED="${CODED_BETA_REQUESTED:-0}"
  export CODED_RELEASE_STATUS="latest"
  export CODED_RELEASE_CHANNEL="latest"
  coded_m1091v51c_print_effective_status
fi

# M1091V50H fallback continues with original public/latest run.sh below.

# M1091V29C3_PUBLIC_MAC_ARM_AUTO_NEON_DEFAULTS
# Public one-liner contract:
#   WALLET=... WORKER=... bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"
# On Apple Silicon, all backend/fullscore/analytics defaults are selected automatically.
CODED_UNAME_S="$(uname -s 2>/dev/null || true)"
CODED_UNAME_M="$(uname -m 2>/dev/null || true)"
if [ "$CODED_UNAME_S" = "Darwin" ] && { [ "$CODED_UNAME_M" = "arm64" ] || [ "$CODED_UNAME_M" = "aarch64" ]; }; then
  export CODED_PLATFORM="${CODED_PLATFORM:-macos-arm64}"
  export CODED_BACKEND="${CODED_BACKEND:-arm-neon}"
  export CODED_KERNEL_BACKEND="${CODED_KERNEL_BACKEND:-arm-neon}"
  export CODED_ARM_NEON_KERNEL="${CODED_ARM_NEON_KERNEL:-compat32}"

  # Universal Analytics must behave like Linux/Windows public backends.
  export CODED_ANALYTICS="${CODED_ANALYTICS:-YES}"
  export CODED_ANALYTICS_ENABLED="${CODED_ANALYTICS_ENABLED:-1}"

  # Mac ARM NEON path is golden-gated real score now.
  export CODED_FORCE_FULLSCORE="${CODED_FORCE_FULLSCORE:-1}"
  export CODED_FULLSCORE_ALL_BACKENDS="${CODED_FULLSCORE_ALL_BACKENDS:-1}"
  export CODED_PREFILTER_DIFFICULTY="${CODED_PREFILTER_DIFFICULTY:-0}"

  # Prefer performance cores if macOS exposes them; otherwise use all logical CPUs.
  if [ -z "${THREADS:-}" ] && [ -z "${CODED_THREADS:-}" ]; then
    CODED_AUTO_THREADS="$(sysctl -n hw.perflevel0.logicalcpu 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)"
    export THREADS="$CODED_AUTO_THREADS"
    export CODED_THREADS="$CODED_AUTO_THREADS"
  else
    export THREADS="${THREADS:-$CODED_THREADS}"
    export CODED_THREADS="${CODED_THREADS:-$THREADS}"
  fi

  # Future policy: metal-gpu may override this only after separate golden validation.
  export CODED_MAC_ARM_AUTO="${CODED_MAC_ARM_AUTO:-1}"
fi

set -euo pipefail
# M1091V44E_CANONICAL_RUN_START_ENV
if [ -z "${CODED_RUN_STARTED_AT:-}" ]; then
  CODED_RUN_STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
fi
if [ -z "${CODED_RUN_ID:-}" ]; then
  _coded_worker_for_run="${CODED_WORKER_NAME:-${WORKER_NAME:-${CODED_WORKER:-${WORKER:-$(hostname 2>/dev/null || echo worker)}}}}"
  _coded_worker_for_run="$(printf "%s" "$_coded_worker_for_run" | tr -cd "A-Za-z0-9_.-")"
  CODED_RUN_ID="RUN_${_coded_worker_for_run}_$(printf "%s" "$CODED_RUN_STARTED_AT" | tr -d ":-" | sed "s/Z$/Z/")"
fi
export CODED_RUN_STARTED_AT CODED_RUN_ID

# M1091V44F_CLEAN_CANONICAL_RUN_ID
RUN_ID="${RUN_ID:-$CODED_RUN_ID}"
CODED_RUN_ID="${CODED_RUN_ID:-$RUN_ID}"
export RUN_ID CODED_RUN_ID

# M1091V28_LINUX_MAC_PUBLIC_RUNNER_CANONICAL_ANALYTICS
# M1091V28B_NO_THRESHOLD_CLI_MAC_ASSET_FALLBACKS
# Public Linux/macOS runner:
# - Linux x86_64 downloads coded-miner-latest.tar.gz
# - Mac ARM downloads coded-miner-macos-arm64.tar.gz
# - Supports shorthand args: -avx2 -2, -avx512 -31, -scalar -1
# - Starts miner + canonical analytics sidecar like Windows/Hive.

BACKEND="${BACKEND:-auto}"
THREADS="${THREADS:-${CODED_THREADS:-0}}"

while [ $# -gt 0 ]; do
  case "$1" in
    -avx2) BACKEND="avx2" ;;
    -avx512) BACKEND="avx512" ;;
    -scalar) BACKEND="scalar" ;;
    -auto) BACKEND="auto" ;;
    -[0-9]*) THREADS="${1#-}" ;;
    --threads=*) THREADS="${1#--threads=}" ;;
    -t=*) THREADS="${1#-t=}" ;;
    --backend=*) BACKEND="${1#--backend=}" ;;
    *) ;;
  esac
  shift
done

WALLET="${WALLET:-${QUBIC_WALLET:-${CODED_WALLET:-}}}"
WORKER="${WORKER:-${QUBIC_WORKER:-${CODED_WORKER:-${CODED_WORKER_NAME:-}}}}"

if [ -z "${WALLET:-}" ] || [ "$WALLET" = "YOUR_QUBIC_WALLET" ]; then
  echo "ERROR: WALLET is required"
  exit 1
fi

if [ -z "${WORKER:-}" ] || [ "$WORKER" = "YOUR_WORKER_NAME" ]; then
  WORKER="$(hostname 2>/dev/null || echo public-worker)"
fi

WORKER_SAFE="$(printf '%s' "$WORKER" | tr -cd 'A-Za-z0-9._-' | cut -c1-64)"
[ -n "$WORKER_SAFE" ] || WORKER_SAFE="public-worker"

POOL="${POOL:-${CODED_POOL:-pool.codedonqubic.com:7777}}"
THRESHOLD="${THRESHOLD:-${CODED_THRESHOLD:-509}}"
API_ROOT="${CODED_POOL_API_BASE:-${API_ROOT:-https://api.codedonqubic.com}}"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m | tr '[:upper:]' '[:lower:]')"

if [ "$THREADS" = "0" ] || [ -z "$THREADS" ]; then
  CPU_COUNT="$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)"
  THREADS="$((CPU_COUNT > 1 ? CPU_COUNT - 1 : 1))"
fi

PLATFORM="linux-amd64"
ASSET_URL="${CODED_LINUX_LATEST_URL:-${CODED_RELEASE_DOWNLOAD_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest.tar.gz}}"

case "$OS/$ARCH" in
  darwin/arm64|darwin/aarch64)
    PLATFORM="macos-arm64"
      # M1091V32A3_PUBLIC_MAC_RELEASE_ASSET_FIRST
      # Prefer real button-published GitHub release assets.
      # Raw main tarballs are fallback only because they can lag behind release/latest.
      ASSET_URL="${CODED_MAC_ARM_LATEST_URL:-${CODED_RELEASE_DOWNLOAD_URL:-${CODED_RELEASE_DOWNLOAD_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64-latest.tar.gz}}}"
      ASSET_URLS="${CODED_MAC_ARM_LATEST_URLS:-${CODED_RELEASE_DOWNLOAD_URL:-${CODED_RELEASE_DOWNLOAD_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64-latest.tar.gz}} ${CODED_RELEASE_DOWNLOAD_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64.tar.gz} ${CODED_RELEASE_DOWNLOAD_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest-macos-arm64.tar.gz} https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/coded-miner-macos-arm64-latest.tar.gz https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/coded-miner-macos-arm64.tar.gz}"
    ;;
  linux/x86_64|linux/amd64)
    PLATFORM="linux-amd64"
    ASSET_URL="${CODED_LINUX_LATEST_URL:-${CODED_RELEASE_DOWNLOAD_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest.tar.gz}}"
    ASSET_URLS="${CODED_LINUX_LATEST_URLS:-${CODED_RELEASE_DOWNLOAD_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest.tar.gz}}"
    ;;
  *)
    echo "ERROR: unsupported platform $OS/$ARCH"
    exit 1
    ;;
esac

BASE="${CODED_BASE_DIR:-$HOME/.coded-miner/public}"
STATE_DIR="$BASE/$WORKER_SAFE"
INSTALL_DIR="$STATE_DIR/latest"
LOG_DIR="$STATE_DIR/logs"
PID_DIR="$STATE_DIR/pids"
TMP_DIR="$STATE_DIR/download.$$"
TAR_FILE="$STATE_DIR/coded-miner.tar.gz"

# M1091V33A_PUBLIC_RUNSH_AUTOUPDATE_300S
# Central public auto-update interval. Override with CODED_PUBLIC_UPDATE_SEC=...
CODED_PUBLIC_UPDATE_SEC="${CODED_PUBLIC_UPDATE_SEC:-60}"
CODED_PUBLIC_RUNSH_URL="${CODED_PUBLIC_RUNSH_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh}"

mkdir -p "$LOG_DIR" "$PID_DIR" "$TMP_DIR"

RUN_ID="PUBLIC_${WORKER_SAFE}_${PLATFORM}_$(date -u +%Y%m%d_%H%M%S)"
RUN_LOG="$LOG_DIR/${RUN_ID}.log"
ANALYTICS_LOG="$LOG_DIR/ANALYTICS_${RUN_ID}.log"

# M1091V33B_PUBLIC_LOADER_SILENT_UPDATE
# M1091V33C_SMOOTH_FULL_WIDTH_LOADER
# M1091V33D_GREEN_LOADER_STATUS_LINE
# M1091V33F_PUBLIC_CONSOLE_FROM_RELEASE_REPO
# M1091V33G_PUBLIC_UPDATE_60S\n# M1091V33H_SELFCONTAINED_RELEASE_CLEANUP
# M1091V33E_SHORTER_LOADER_SEQUENCE
CODED_PUBLIC_BOOT_SEC="${CODED_PUBLIC_BOOT_SEC:-10}"
CODED_PUBLIC_BOOT_STATUS="${CODED_PUBLIC_BOOT_STATUS:-Initializing latest CODED MINER}"

coded_ui_box() {
  local title="${1:-CODED}"

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$title" <<'PYBOX'
import sys
title = sys.argv[1]
width = 78
line = "═" * width
pad = max(0, width - len(title))
left = pad // 2
right = pad - left
print("")
print("╔" + line + "╗")
print("║" + (" " * left) + title + (" " * right) + "║")
print("╚" + line + "╝")
print("")
PYBOX
  else
    printf '\n==============================\n%s\n==============================\n\n' "$title"
  fi
}

coded_ui_loader_started=0
coded_ui_loader_percent=0

coded_ui_loader_render() {
  local percent="${1:-0}"
  local status="${2:-Starting CODED}"

  if [ "$coded_ui_loader_started" = "1" ]; then
    printf '\033[2A'
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$percent" "$status" <<'PYLOAD'
import sys

percent = int(float(sys.argv[1]))
status = sys.argv[2]

width = 78
percent = max(0, min(100, percent))
fill = int(width * percent / 100)

green = "\033[38;5;46m"
dim_green = "\033[38;5;22m"
reset = "\033[0m"

bar = green + ("█" * fill) + dim_green + ("░" * (width - fill)) + reset
status_line = f"{percent:3d}% {status}"
status_line = status_line[:width].center(width)

print("\r\033[K" + bar)
print("\r\033[K" + status_line)
PYLOAD
  else
    printf '\r\033[K'
    local width=78
    local fill=$((width * percent / 100))
    local i=0
    while [ "$i" -lt "$width" ]; do
      if [ "$i" -lt "$fill" ]; then
        printf '█'
      else
        printf '░'
      fi
      i=$((i + 1))
    done
    printf '\n\r\033[K%3s%% %s\n' "$percent" "$status"
  fi

  coded_ui_loader_started=1
}

coded_ui_loader() {
  local target="${1:-0}"
  local status="${2:-Starting CODED}"

  case "$target" in
    ''|*[!0-9]*)
      target=0
    ;;
  esac

  if [ "$target" -lt 0 ]; then
    target=0
  fi

  if [ "$target" -gt 100 ]; then
    target=100
  fi

  local cur="${coded_ui_loader_percent:-0}"

  if [ "$target" -lt "$cur" ]; then
    cur=0
    coded_ui_loader_percent=0
  fi

  while [ "$cur" -lt "$target" ]; do
    cur=$((cur + 1))
    if [ "$cur" -gt "$target" ]; then
      cur="$target"
    fi
    coded_ui_loader_render "$cur" "$status"
    sleep 0.012
  done

  coded_ui_loader_render "$target" "$status"
  coded_ui_loader_percent="$target"
}

coded_ui_loader_finish() {
  if [ "$coded_ui_loader_started" = "1" ]; then
    printf '\n'
  fi
  coded_ui_loader_started=0
}

coded_ui_warmup() {
  local seconds="${1:-10}"
  local i=0

  case "$seconds" in
    ''|*[!0-9]*)
      seconds=10
    ;;
  esac

  if [ "$seconds" -lt 1 ]; then
    return 0
  fi

  while [ "$i" -lt "$seconds" ]; do
    i=$((i + 1))
    pct=$((82 + (i * 17 / seconds)))
    if [ "$pct" -gt 99 ]; then
      pct=99
    fi
    coded_ui_loader "$pct" "Stabilizing neural network training"
    sleep 1
  done
}

coded_ui_box '$0.01  IS  CODED'
coded_ui_loader 8 "$CODED_PUBLIC_BOOT_STATUS"

# M1091V32E_STOP_ALL_PUBLIC_INSTANCES
# Public one-liner policy:
# A new public CODED start replaces all previous public CODED starts on this device.
# Scope is strictly CODED_BASE_DIR / ~/.coded-miner/public, so Hive/builders are not touched.
coded_stop_old_public_instances() {
  local base="${1:-}"
  [ -n "$base" ] || return 0

  coded_ui_loader 18 "Stopping previous CODED session"

  if [ -d "$base" ]; then
    find "$base" -type f \( -name "miner.pid" -o -name "analytics.pid" \) -path "$base/*/pids/*" -print 2>/dev/null | while read -r pf; do
      local pid
      pid="$(cat "$pf" 2>/dev/null || true)"
      if [ -n "$pid" ]; then
        kill "$pid" 2>/dev/null || true
      fi
      rm -f "$pf" 2>/dev/null || true
    done
  fi

  local needle pid cmd
  for needle in coded-miner coded-runtime-sidecar.py coded-public-console.py; do
    pgrep -f "$needle" 2>/dev/null | while read -r pid; do
      cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
      case "$cmd" in
        *"$base"/*"/latest/"*)
          kill "$pid" 2>/dev/null || true
        ;;
      esac
    done
  done

  sleep 1

  for needle in coded-miner coded-runtime-sidecar.py coded-public-console.py; do
    pgrep -f "$needle" 2>/dev/null | while read -r pid; do
      cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
      case "$cmd" in
        *"$base"/*"/latest/"*)
          kill -9 "$pid" 2>/dev/null || true
        ;;
      esac
    done
  done
}

coded_stop_old_public_instances "$BASE"

coded_ui_loader 32 "Downloading latest CODED MINER"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

DOWNLOAD_OK=0
for u in ${CODED_RELEASE_DOWNLOAD_URL:-} ${ASSET_URLS:-$ASSET_URL}; do
  if curl -fsSL --retry 3 "$u" -o "$TAR_FILE"; then
    DOWNLOAD_OK=1
    ASSET_URL="$u"
    break
  fi
done

if [ "$DOWNLOAD_OK" != "1" ]; then
  echo "ERROR: could not download CODED package for $PLATFORM"
  echo "Tried: ${ASSET_URLS:-$ASSET_URL}"
  exit 1
fi

tar -xzf "$TAR_FILE" -C "$TMP_DIR"

ROOT="$TMP_DIR"
if [ -d "$TMP_DIR/coded-miner" ]; then
  ROOT="$TMP_DIR/coded-miner"
fi

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -R "$ROOT"/. "$INSTALL_DIR"/
chmod +x "$INSTALL_DIR"/* 2>/dev/null || true

coded_ui_loader 55 "Setting up environment"

# M1091V32H_FORCE_PUBLIC_CONSOLE_NO_RAW_FALLBACK
# A bad/rebuilt asset must never expose raw dev analytics in the public terminal.
# If the package misses coded-public-console.py, fetch it directly from coded-miner-release.
coded_ensure_public_console() {
  # M1091V33H_SELFCONTAINED_RELEASE_CLEANUP
  # run.sh is self-contained: if the release asset misses coded-public-console.py,
  # write the bundled public console directly from this script.
  if [ -f "$INSTALL_DIR/coded-public-console.py" ]; then
    chmod +x "$INSTALL_DIR/coded-public-console.py" 2>/dev/null || true
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$INSTALL_DIR/coded-public-console.py" <<'PYCONSOLE'
import base64
import pathlib
import sys

data = """IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwojIE0xMDkxVjMyQ19QVUJMSUNfQ09OU09MRV9QT0xJU0gKCmltcG9ydCBvcwppbXBvcnQgcmUKaW1wb3J0IHN5cwppbXBvcnQgdGltZQpmcm9tIHR5cGluZyBpbXBvcnQgRGljdCwgT3B0aW9uYWwKCk1BUktFUiA9ICJNMTA5MVYzMkNfUFVCTElDX0NPTlNPTEVfUE9MSVNIIgoKQlJBTkRfRVZFUlkgPSBpbnQob3MuZW52aXJvbi5nZXQoIkNPREVEX1BVQkxJQ19CUkFORF9FVkVSWSIsICI5Iikgb3IgIjkiKQpMSU5FX1NFQyA9IGZsb2F0KG9zLmVudmlyb24uZ2V0KCJDT0RFRF9QVUJMSUNfTElORV9TRUMiLCAiMSIpIG9yICIxIikKQlJBTkRfV0lEVEggPSBpbnQob3MuZW52aXJvbi5nZXQoIkNPREVEX1BVQkxJQ19CUkFORF9XSURUSCIsICI3OCIpIG9yICI3OCIpCgppZiBCUkFORF9XSURUSCA8IDU2OgogICAgQlJBTkRfV0lEVEggPSA1NgoKCmRlZiBlbnZfYW55KCpuYW1lczogc3RyLCBkZWZhdWx0OiBzdHIgPSAiIikgLT4gc3RyOgogICAgZm9yIG4gaW4gbmFtZXM6CiAgICAgICAgdiA9IG9zLmVudmlyb24uZ2V0KG4pCiAgICAgICAgaWYgdiBpcyBub3QgTm9uZSBhbmQgc3RyKHYpLnN0cmlwKCkgIT0gIiI6CiAgICAgICAgICAgIHJldHVybiBzdHIodikuc3RyaXAoKQogICAgcmV0dXJuIGRlZmF1bHQKCgpkZWYga3ZfcGFyc2UobGluZTogc3RyKSAtPiBEaWN0W3N0ciwgc3RyXToKICAgIG91dDogRGljdFtzdHIsIHN0cl0gPSB7fQogICAgZm9yIGssIHYgaW4gcmUuZmluZGFsbChyJyhbQS1aYS16MC05X10rKT0oIlteIl0qInxbXiBcdFxyXG5dKyknLCBsaW5lKToKICAgICAgICBpZiBsZW4odikgPj0gMiBhbmQgdlswXSA9PSAnIicgYW5kIHZbLTFdID09ICciJzoKICAgICAgICAgICAgdiA9IHZbMTotMV0KICAgICAgICBvdXRba10gPSB2CiAgICByZXR1cm4gb3V0CgoKZGVmIGZudW0odiwgZGVmYXVsdDogZmxvYXQgPSAwLjApIC0+IGZsb2F0OgogICAgdHJ5OgogICAgICAgIGlmIHYgaXMgTm9uZToKICAgICAgICAgICAgcmV0dXJuIGRlZmF1bHQKICAgICAgICByZXR1cm4gZmxvYXQoc3RyKHYpLnN0cmlwKCkpCiAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgIHJldHVybiBkZWZhdWx0CgoKZGVmIGludW0odiwgZGVmYXVsdDogaW50ID0gMCkgLT4gaW50OgogICAgdHJ5OgogICAgICAgIGlmIHYgaXMgTm9uZToKICAgICAgICAgICAgcmV0dXJuIGRlZmF1bHQKICAgICAgICByZXR1cm4gaW50KGZsb2F0KHN0cih2KS5zdHJpcCgpKSkKICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgcmV0dXJuIGRlZmF1bHQKCgpkZWYgZm10X3JhdGUodjogZmxvYXQpIC0+IHN0cjoKICAgIHYgPSBmbG9hdCh2IG9yIDAuMCkKCiAgICBpZiB2ID49IDFfMDAwXzAwMF8wMDA6CiAgICAgICAgcyA9IGYie3YgLyAxXzAwMF8wMDBfMDAwOi4yZn1HIgogICAgZWxpZiB2ID49IDFfMDAwXzAwMDoKICAgICAgICBzID0gZiJ7diAvIDFfMDAwXzAwMDouMmZ9TSIKICAgIGVsaWYgdiA+PSAxXzAwMDoKICAgICAgICBzID0gZiJ7diAvIDFfMDAwOi4yZn1LIgogICAgZWxzZToKICAgICAgICBzID0gZiJ7djouMGZ9IgoKICAgIHJldHVybiBzLnJlcGxhY2UoIi4iLCAiLCIpCgoKZGVmIGNhbm9uX2JhY2tlbmQocmF3OiBzdHIsIHBsYXRmb3JtOiBzdHIgPSAiIikgLT4gc3RyOgogICAgciA9IChyYXcgb3IgIiIpLnN0cmlwKCkubG93ZXIoKQogICAgcCA9IChwbGF0Zm9ybSBvciAiIikuc3RyaXAoKS5sb3dlcigpCgogICAgaWYgImN1ZGEiIGluIHI6CiAgICAgICAgcmV0dXJuICJDVURBIgogICAgaWYgImF2eDUxMiIgaW4gciBvciAiYXZ4LTUxMiIgaW4gcjoKICAgICAgICByZXR1cm4gIkFWWDUxMiIKICAgIGlmICJhdngyIiBpbiByOgogICAgICAgIHJldHVybiAiQVZYMiIKICAgIGlmICJhcm0iIGluIHIgb3IgIm5lb24iIGluIHIgb3IgcC5zdGFydHN3aXRoKCJtYWNvcy1hcm0iKSBvciBwLnN0YXJ0c3dpdGgoImRhcndpbiIpOgogICAgICAgIHJldHVybiAiQVJNIgoKICAgIHJldHVybiAiU0NBTEFSIgoKCmRlZiBjbGVhbl9lcG9jaCh2OiBzdHIpIC0+IHN0cjoKICAgIHYgPSAodiBvciAiIikuc3RyaXAoKQogICAgaWYgbm90IHYgb3Igdi5sb3dlcigpIGluICgiYXV0byIsICJub25lIiwgIm51bGwiLCAidW5rbm93biIpOgogICAgICAgIHJldHVybiAiPyIKICAgIHJldHVybiB2CgoKZGVmIGN1cnJlbnRfcXViaWNfZXBvY2hfZmFsbGJhY2soKSAtPiBzdHI6CiAgICAjIE0xMDkxVjMyRl9FUE9DSF9GQUxMQkFDS19TSE9SVF9TVEFUVVNfTElORQogICAgIyBRdWJpYyBlcG9jaCBjaGFuZ2VzIHdlZWtseSBvbiBXZWRuZXNkYXkgMTI6MDAgVVRDLgogICAgIyBVc2VyLXZlcmlmaWVkIHJlZmVyZW5jZTogZXBvY2ggMjIwIGlzIGFjdGl2ZSBhZnRlciAyMDI2LTA3LTAxIDEyOjAwIFVUQy4KICAgIHRyeToKICAgICAgICByZWZfZXBvY2ggPSAyMjAKICAgICAgICByZWZfdXRjID0gdGltZS5ta3RpbWUodGltZS5zdHJwdGltZSgiMjAyNi0wNy0wMSAxMjowMDowMCIsICIlWS0lbS0lZCAlSDolTTolUyIpKQogICAgICAgICMgdGltZS5ta3RpbWUgdXNlcyBsb2NhbCB0aW1lLiBDb3JyZWN0IGJ5IHVzaW5nIHRpbWV6b25lIG9mZnNldCB2aWEgY2FsZW5kYXItZnJlZSBVVEMgYXBwcm94aW1hdGlvbi4KICAgICAgICAjIFNhZmVyOiBidWlsZCBVVEMgdGltZXN0YW1wIHdpdGggUHl0aG9uIGRhdGV0aW1lIGlmIGF2YWlsYWJsZS4KICAgICAgICBpbXBvcnQgY2FsZW5kYXIKICAgICAgICByZWZfdHVwbGUgPSB0aW1lLnN0cnB0aW1lKCIyMDI2LTA3LTAxIDEyOjAwOjAwIiwgIiVZLSVtLSVkICVIOiVNOiVTIikKICAgICAgICByZWZfdHMgPSBjYWxlbmRhci50aW1lZ20ocmVmX3R1cGxlKQogICAgICAgIG5vd190cyA9IHRpbWUudGltZSgpCiAgICAgICAgZGVsdGFfd2Vla3MgPSBpbnQoKG5vd190cyAtIHJlZl90cykgLy8gNjA0ODAwKQogICAgICAgIHJldHVybiBzdHIocmVmX2Vwb2NoICsgZGVsdGFfd2Vla3MpCiAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgIHJldHVybiAiPyIKCgpkZWYgZXBvY2hfb3JfZmFsbGJhY2sodjogc3RyKSAtPiBzdHI6CiAgICBjbGVhbmVkID0gY2xlYW5fZXBvY2godikKICAgIGlmIGNsZWFuZWQgIT0gIj8iOgogICAgICAgIHJldHVybiBjbGVhbmVkCiAgICByZXR1cm4gY3VycmVudF9xdWJpY19lcG9jaF9mYWxsYmFjaygpCgoKZGVmIHByaW50X2JyYW5kKCkgLT4gTm9uZToKICAgIHRpdGxlID0gIiQwLjAxICBJUyAgQ09ERUQiCiAgICBsaW5lID0gIuKVkCIgKiBCUkFORF9XSURUSAogICAgcGFkID0gbWF4KDAsIEJSQU5EX1dJRFRIIC0gbGVuKHRpdGxlKSkKICAgIGxlZnQgPSBwYWQgLy8gMgogICAgcmlnaHQgPSBwYWQgLSBsZWZ0CgogICAgcHJpbnQoIiIpCiAgICBwcmludChmIuKVlHtsaW5lfeKVlyIpCiAgICBwcmludChmIuKVkXsnICcgKiBsZWZ0fXt0aXRsZX17JyAnICogcmlnaHR94pWRIikKICAgIHByaW50KGYi4pWae2xpbmV94pWdIikKICAgIHByaW50KCIiLCBmbHVzaD1UcnVlKQoKCmNsYXNzIFB1YmxpY1N0YXRlOgogICAgZGVmIF9faW5pdF9fKHNlbGYpIC0+IE5vbmU6CiAgICAgICAgc2VsZi53b3JrZXIgPSBlbnZfYW55KCJDT0RFRF9XT1JLRVJfTkFNRSIsICJXT1JLRVIiLCAiUklHX0lEIiwgIkNPREVEX1JJR19JRCIsIGRlZmF1bHQ9ImNvZGVkLXdvcmtlciIpCiAgICAgICAgc2VsZi53YWxsZXQgPSBlbnZfYW55KCJDT0RFRF9XQUxMRVQiLCAiV0FMTEVUIiwgIlFVQklDX1dBTExFVCIsIGRlZmF1bHQ9Im5vdCBzZXQiKQogICAgICAgIHNlbGYudGhyZWFkcyA9IGVudl9hbnkoIkNPREVEX1RIUkVBRFMiLCAiVEhSRUFEUyIsIGRlZmF1bHQ9Ij8iKQogICAgICAgIHNlbGYuZW52X2JhY2tlbmQgPSBlbnZfYW55KCJDT0RFRF9TRUxFQ1RFRF9CQUNLRU5EIiwgIkNPREVEX0tFUk5FTF9CQUNLRU5EIiwgIkNPREVEX0JBQ0tFTkQiLCAiQkFDS0VORCIsIGRlZmF1bHQ9IiIpCiAgICAgICAgc2VsZi5mcmFtZV9iYWNrZW5kID0gIiIKICAgICAgICBzZWxmLnBsYXRmb3JtID0gZW52X2FueSgiQ09ERURfUExBVEZPUk0iLCBkZWZhdWx0PXN5cy5wbGF0Zm9ybSkKICAgICAgICBzZWxmLmVwb2NoID0gZXBvY2hfb3JfZmFsbGJhY2soZW52X2FueSgiUVVCSUNfRVBPQ0giLCAiQ09ERURfRVBPQ0giLCAiQ09ERURfUFVCTElDX0VQT0NIIiwgZGVmYXVsdD0iPyIpKQogICAgICAgIHNlbGYucHJpbnRlZF9oZWFkZXIgPSBGYWxzZQogICAgICAgIHNlbGYuc3RhdHVzX2NvdW50ID0gMAogICAgICAgIHNlbGYubGF0ZXN0X2ZyYW1lOiBPcHRpb25hbFtEaWN0W3N0ciwgc3RyXV0gPSBOb25lCiAgICAgICAgc2VsZi5sYXN0X2VtaXQgPSAwLjAKCiAgICBkZWYgYmFja2VuZF9sYWJlbChzZWxmKSAtPiBzdHI6CiAgICAgICAgc291cmNlID0gc2VsZi5lbnZfYmFja2VuZCBvciBzZWxmLmZyYW1lX2JhY2tlbmQKICAgICAgICByZXR1cm4gY2Fub25fYmFja2VuZChzb3VyY2UsIHNlbGYucGxhdGZvcm0pCgogICAgZGVmIHVwZGF0ZV9mcm9tX2FueV9saW5lKHNlbGYsIGxpbmU6IHN0cikgLT4gTm9uZToKICAgICAgICBkYXRhID0ga3ZfcGFyc2UobGluZSkKCiAgICAgICAgaWYgZGF0YS5nZXQoIndvcmtlciIpOgogICAgICAgICAgICBzZWxmLndvcmtlciA9IGRhdGFbIndvcmtlciJdCiAgICAgICAgaWYgZGF0YS5nZXQoInRocmVhZHMiKToKICAgICAgICAgICAgc2VsZi50aHJlYWRzID0gZGF0YVsidGhyZWFkcyJdCiAgICAgICAgaWYgZGF0YS5nZXQoInBsYXRmb3JtIik6CiAgICAgICAgICAgIHNlbGYucGxhdGZvcm0gPSBkYXRhWyJwbGF0Zm9ybSJdCiAgICAgICAgaWYgZGF0YS5nZXQoImVwb2NoIik6CiAgICAgICAgICAgIHNlbGYuZXBvY2ggPSBlcG9jaF9vcl9mYWxsYmFjayhkYXRhWyJlcG9jaCJdKQogICAgICAgIGlmIGRhdGEuZ2V0KCJiYWNrZW5kIik6CiAgICAgICAgICAgIHNlbGYuZnJhbWVfYmFja2VuZCA9IGRhdGFbImJhY2tlbmQiXQoKICAgIGRlZiB1cGRhdGVfZnJvbV9mcmFtZShzZWxmLCBmcmFtZTogRGljdFtzdHIsIHN0cl0pIC0+IE5vbmU6CiAgICAgICAgc2VsZi53b3JrZXIgPSBmcmFtZS5nZXQoIndvcmtlciIpIG9yIHNlbGYud29ya2VyCiAgICAgICAgc2VsZi5mcmFtZV9iYWNrZW5kID0gZnJhbWUuZ2V0KCJiYWNrZW5kIikgb3Igc2VsZi5mcmFtZV9iYWNrZW5kCiAgICAgICAgc2VsZi50aHJlYWRzID0gZnJhbWUuZ2V0KCJ0aHJlYWRzIikgb3Igc2VsZi50aHJlYWRzCiAgICAgICAgc2VsZi5wbGF0Zm9ybSA9IGZyYW1lLmdldCgicGxhdGZvcm0iKSBvciBzZWxmLnBsYXRmb3JtCiAgICAgICAgc2VsZi5lcG9jaCA9IGVwb2NoX29yX2ZhbGxiYWNrKGZyYW1lLmdldCgiZXBvY2giKSBvciBzZWxmLmVwb2NoKQogICAgICAgIHNlbGYubGF0ZXN0X2ZyYW1lID0gZnJhbWUKCiAgICBkZWYgaGVhZGVyKHNlbGYpIC0+IE5vbmU6CiAgICAgICAgaWYgc2VsZi5wcmludGVkX2hlYWRlcjoKICAgICAgICAgICAgcmV0dXJuCgogICAgICAgIHByaW50X2JyYW5kKCkKICAgICAgICBwcmludCgiQ09ERUQgUFVCTElDIE1JTkVSIikKICAgICAgICBwcmludChmIndhbGxldCAgOiB7c2VsZi53YWxsZXR9IikKICAgICAgICBwcmludChmIndvcmtlciAgOiB7c2VsZi53b3JrZXJ9IikKICAgICAgICBwcmludChmInRocmVhZHMgOiB7c2VsZi50aHJlYWRzfSIpCiAgICAgICAgcHJpbnQoZiJiYWNrZW5kIDoge3NlbGYuYmFja2VuZF9sYWJlbCgpfSIpCiAgICAgICAgcHJpbnQoZiJlcG9jaCAgIDoge3NlbGYuZXBvY2h9IikKICAgICAgICBwcmludCgiIikKCiAgICAgICAgc2VsZi5wcmludGVkX2hlYWRlciA9IFRydWUKICAgICAgICBzeXMuc3Rkb3V0LmZsdXNoKCkKCiAgICBkZWYgcmVuZGVyX2xhdGVzdChzZWxmKSAtPiBOb25lOgogICAgICAgIGlmIG5vdCBzZWxmLmxhdGVzdF9mcmFtZToKICAgICAgICAgICAgcmV0dXJuCgogICAgICAgIG5vdyA9IHRpbWUudGltZSgpCiAgICAgICAgaWYgKG5vdyAtIHNlbGYubGFzdF9lbWl0KSA8IExJTkVfU0VDOgogICAgICAgICAgICByZXR1cm4KCiAgICAgICAgc2VsZi5sYXN0X2VtaXQgPSBub3cKCiAgICAgICAgaWYgbm90IHNlbGYucHJpbnRlZF9oZWFkZXI6CiAgICAgICAgICAgIHNlbGYuaGVhZGVyKCkKCiAgICAgICAgc2VsZi5zdGF0dXNfY291bnQgKz0gMQoKICAgICAgICBpZiBzZWxmLnN0YXR1c19jb3VudCA+IDEgYW5kIChzZWxmLnN0YXR1c19jb3VudCAtIDEpICUgQlJBTkRfRVZFUlkgPT0gMDoKICAgICAgICAgICAgcHJpbnRfYnJhbmQoKQoKICAgICAgICBmcmFtZSA9IHNlbGYubGF0ZXN0X2ZyYW1lCgogICAgICAgIHRvdGFsID0gZm51bSgKICAgICAgICAgICAgZnJhbWUuZ2V0KCJoYXNoX2l0X3MiKQogICAgICAgICAgICBvciBmcmFtZS5nZXQoInRvdGFsX2l0X3MiKQogICAgICAgICAgICBvciBmcmFtZS5nZXQoInJhd19pdF9zIikKICAgICAgICAgICAgb3IgZnJhbWUuZ2V0KCJiYWNrZW5kX2hvdGxvb3BfaXRfcyIpCiAgICAgICAgICAgIG9yIGZyYW1lLmdldCgicGlwZWxpbmVfaXRfcyIpCiAgICAgICAgKQoKICAgICAgICBhdmcgPSBmbnVtKGZyYW1lLmdldCgiYXZnX2hhc2hfaXRfc18zMHMiKSwgdG90YWwpCgogICAgICAgIHNvbHMgPSBpbnVtKAogICAgICAgICAgICBmcmFtZS5nZXQoInNvbHV0aW9ucyIpCiAgICAgICAgICAgIG9yIGZyYW1lLmdldCgic29scyIpCiAgICAgICAgICAgIG9yIGZyYW1lLmdldCgidG90YWxfcGFzcyIpCiAgICAgICAgICAgIG9yIGZyYW1lLmdldCgicmVhbDMwMCIpCiAgICAgICAgICAgIG9yIDAKICAgICAgICApCgogICAgICAgIGFjY2VwdGVkID0gaW51bSgKICAgICAgICAgICAgZnJhbWUuZ2V0KCJhY2NlcHRlZCIpCiAgICAgICAgICAgIG9yIGZyYW1lLmdldCgicG9vbF9hY2NlcHRlZCIpCiAgICAgICAgICAgIG9yIGZyYW1lLmdldCgiYWNjZXB0ZWRfdG90YWwiKQogICAgICAgICAgICBvciBmcmFtZS5nZXQoInRvdGFsX2FjY2VwdGVkIikKICAgICAgICAgICAgb3IgZnJhbWUuZ2V0KCJhY2NlcHRlZF9zb2x1dGlvbnMiKQogICAgICAgICAgICBvciBmcmFtZS5nZXQoInRvdGFsX3Bhc3MiKQogICAgICAgICAgICBvciAwCiAgICAgICAgKQoKICAgICAgICByZWplY3RlZCA9IGludW0oCiAgICAgICAgICAgIGZyYW1lLmdldCgicmVqZWN0ZWQiKQogICAgICAgICAgICBvciBmcmFtZS5nZXQoInBvb2xfcmVqZWN0ZWQiKQogICAgICAgICAgICBvciBmcmFtZS5nZXQoInJlamVjdGVkX3RvdGFsIikKICAgICAgICAgICAgb3IgZnJhbWUuZ2V0KCJ0b3RhbF9yZWplY3RlZCIpCiAgICAgICAgICAgIG9yIDAKICAgICAgICApCgogICAgICAgIGNsb2NrID0gdGltZS5zdHJmdGltZSgiJUg6JU06JVMiLCB0aW1lLmxvY2FsdGltZSgpKQogICAgICAgIGVwb2NoID0gZXBvY2hfb3JfZmFsbGJhY2soZnJhbWUuZ2V0KCJlcG9jaCIpIG9yIHNlbGYuZXBvY2gpCiAgICAgICAgYmFja2VuZCA9IHNlbGYuYmFja2VuZF9sYWJlbCgpCgogICAgICAgICMgTTEwOTFWMzJNX0RZTkFNSUNfR0FQX0FGVEVSX0xPR08KICAgICAgICAjIEtlZXAgbG9nIGxpbmVzIHVuYm94ZWQgYW5kIGV4YWN0bHkgYXMgd2lkZSBhcyB0aGUgYnJhbmRpbmcgaW5uZXIgd2lkdGguCiAgICAgICAgIyBBbnkgc3BhcmUgc3BhY2UgaXMgcGxhY2VkIGFmdGVyIFskMC4wMV0sIHNvIGhhc2hyYXRlL1NPTFMgY2hhbmdlcyBzaHJpbmsvZ3JvdwogICAgICAgICMgdGhlIHZpc3VhbCBnYXAgd2l0aG91dCBtb3ZpbmcgdGhlIHJpZ2h0IGVkZ2UuCiAgICAgICAgdG90YWxfcyA9IGZtdF9yYXRlKHRvdGFsKQogICAgICAgIGF2Z19zID0gZm10X3JhdGUoYXZnKQoKICAgICAgICBsb2dvID0gIlskMC4wMV0iCiAgICAgICAgYm9keSA9ICgKICAgICAgICAgICAgZiJ7Y2xvY2t9IEU6e3N0cihlcG9jaCk6PjN9IHwgIgogICAgICAgICAgICBmIlNPTFMge3NvbHN9L3thY2NlcHRlZH0gUjp7cmVqZWN0ZWR9IHwgIgogICAgICAgICAgICBmIntiYWNrZW5kfSB8ICIKICAgICAgICAgICAgZiJ7dG90YWxfc30gaXQvcyB8IEFWRyB7YXZnX3N9IGl0L3MiCiAgICAgICAgKQoKICAgICAgICBnYXAgPSBCUkFORF9XSURUSCAtIGxlbihsb2dvKSAtIGxlbihib2R5KQogICAgICAgIGlmIGdhcCA8IDE6CiAgICAgICAgICAgIGJvZHkgPSAoCiAgICAgICAgICAgICAgICBmIntjbG9ja30gRTp7c3RyKGVwb2NoKTo+M30gfCAiCiAgICAgICAgICAgICAgICBmIlMge3NvbHN9L3thY2NlcHRlZH0gUjp7cmVqZWN0ZWR9IHwgIgogICAgICAgICAgICAgICAgZiJ7YmFja2VuZH0gfCAiCiAgICAgICAgICAgICAgICBmInt0b3RhbF9zfSBpdC9zIHwgQVZHIHthdmdfc30gaXQvcyIKICAgICAgICAgICAgKQogICAgICAgICAgICBnYXAgPSBCUkFORF9XSURUSCAtIGxlbihsb2dvKSAtIGxlbihib2R5KQoKICAgICAgICBpZiBnYXAgPCAxOgogICAgICAgICAgICBib2R5ID0gKAogICAgICAgICAgICAgICAgZiJ7Y2xvY2t9IEU6e3N0cihlcG9jaCk6PjN9fCIKICAgICAgICAgICAgICAgIGYiU3tzb2xzfS97YWNjZXB0ZWR9IFJ7cmVqZWN0ZWR9fCIKICAgICAgICAgICAgICAgIGYie2JhY2tlbmR9fCIKICAgICAgICAgICAgICAgIGYie3RvdGFsX3N9IGl0L3N8QVZHIHthdmdfc30gaXQvcyIKICAgICAgICAgICAgKQogICAgICAgICAgICBnYXAgPSBCUkFORF9XSURUSCAtIGxlbihsb2dvKSAtIGxlbihib2R5KQoKICAgICAgICBpZiBnYXAgPCAxOgogICAgICAgICAgICBnYXAgPSAxCgogICAgICAgIHN0YXR1c19saW5lID0gbG9nbyArICgiICIgKiBnYXApICsgYm9keQoKICAgICAgICBpZiBsZW4oc3RhdHVzX2xpbmUpID4gQlJBTkRfV0lEVEg6CiAgICAgICAgICAgIHN0YXR1c19saW5lID0gc3RhdHVzX2xpbmVbOkJSQU5EX1dJRFRIXQoKICAgICAgICBwcmludChzdGF0dXNfbGluZS5sanVzdChCUkFORF9XSURUSCksIGZsdXNoPVRydWUpCgoKZGVmIHByb2Nlc3NfbGluZShzdGF0ZTogUHVibGljU3RhdGUsIGxpbmU6IHN0cikgLT4gTm9uZToKICAgIHN0YXRlLnVwZGF0ZV9mcm9tX2FueV9saW5lKGxpbmUpCgogICAgaWYgIltDT0RFRF9BTkFMWVRJQ1NfRlJBTUVdIiBub3QgaW4gbGluZToKICAgICAgICByZXR1cm4KCiAgICBmcmFtZSA9IGt2X3BhcnNlKGxpbmUpCiAgICBpZiBub3QgZnJhbWU6CiAgICAgICAgcmV0dXJuCgogICAgc3RhdGUudXBkYXRlX2Zyb21fZnJhbWUoZnJhbWUpCgoKZGVmIHBpZF9hbGl2ZShwaWQ6IGludCkgLT4gYm9vbDoKICAgIGlmIHBpZCA8PSAwOgogICAgICAgIHJldHVybiBUcnVlCgogICAgdHJ5OgogICAgICAgIG9zLmtpbGwocGlkLCAwKQogICAgICAgIHJldHVybiBUcnVlCiAgICBleGNlcHQgUHJvY2Vzc0xvb2t1cEVycm9yOgogICAgICAgIHJldHVybiBGYWxzZQogICAgZXhjZXB0IFBlcm1pc3Npb25FcnJvcjoKICAgICAgICByZXR1cm4gVHJ1ZQogICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICByZXR1cm4gRmFsc2UKCgpkZWYgZm9sbG93KHBhdGg6IHN0ciwgY2hpbGRfcGlkOiBpbnQgPSAwKSAtPiBpbnQ6CiAgICBzdGF0ZSA9IFB1YmxpY1N0YXRlKCkKICAgIHN0YXRlLmhlYWRlcigpCgogICAgcG9zID0gMAogICAgcXVpZXRfYWZ0ZXJfZXhpdCA9IDAKCiAgICB3aGlsZSBUcnVlOgogICAgICAgIHRyeToKICAgICAgICAgICAgd2l0aCBvcGVuKHBhdGgsICJyIiwgZXJyb3JzPSJyZXBsYWNlIikgYXMgZjoKICAgICAgICAgICAgICAgIGYuc2Vlayhwb3MpCgogICAgICAgICAgICAgICAgd2hpbGUgVHJ1ZToKICAgICAgICAgICAgICAgICAgICBsaW5lID0gZi5yZWFkbGluZSgpCiAgICAgICAgICAgICAgICAgICAgaWYgbm90IGxpbmU6CiAgICAgICAgICAgICAgICAgICAgICAgIGJyZWFrCgogICAgICAgICAgICAgICAgICAgIHBvcyA9IGYudGVsbCgpCiAgICAgICAgICAgICAgICAgICAgcHJvY2Vzc19saW5lKHN0YXRlLCBsaW5lLnJzdHJpcCgiXG4iKSkKICAgICAgICBleGNlcHQgRmlsZU5vdEZvdW5kRXJyb3I6CiAgICAgICAgICAgIHBhc3MKCiAgICAgICAgc3RhdGUucmVuZGVyX2xhdGVzdCgpCgogICAgICAgIGlmIGNoaWxkX3BpZCA+IDAgYW5kIG5vdCBwaWRfYWxpdmUoY2hpbGRfcGlkKToKICAgICAgICAgICAgcXVpZXRfYWZ0ZXJfZXhpdCArPSAxCiAgICAgICAgICAgIGlmIHF1aWV0X2FmdGVyX2V4aXQgPj0gNDoKICAgICAgICAgICAgICAgIHJldHVybiAwCiAgICAgICAgZWxzZToKICAgICAgICAgICAgcXVpZXRfYWZ0ZXJfZXhpdCA9IDAKCiAgICAgICAgdGltZS5zbGVlcCgwLjIwKQoKCmRlZiBtYWluKCkgLT4gaW50OgogICAgaWYgbGVuKHN5cy5hcmd2KSA8IDI6CiAgICAgICAgcHJpbnQoZiJ7TUFSS0VSfTogdXNhZ2UgY29kZWQtcHVibGljLWNvbnNvbGUucHkgSU5URVJOQUxfTE9HIFtDSElMRF9QSURdIiwgZmlsZT1zeXMuc3RkZXJyKQogICAgICAgIHJldHVybiAyCgogICAgcGF0aCA9IHN5cy5hcmd2WzFdCgogICAgY2hpbGRfcGlkID0gMAogICAgaWYgbGVuKHN5cy5hcmd2KSA+PSAzOgogICAgICAgIHRyeToKICAgICAgICAgICAgY2hpbGRfcGlkID0gaW50KHN5cy5hcmd2WzJdKQogICAgICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgICAgIGNoaWxkX3BpZCA9IDAKCiAgICB0cnk6CiAgICAgICAgcmV0dXJuIGZvbGxvdyhwYXRoLCBjaGlsZF9waWQpCiAgICBleGNlcHQgS2V5Ym9hcmRJbnRlcnJ1cHQ6CiAgICAgICAgcmV0dXJuIDEzMAoKCmlmIF9fbmFtZV9fID09ICJfX21haW5fXyI6CiAgICByYWlzZSBTeXN0ZW1FeGl0KG1haW4oKSkK"""
path = pathlib.Path(sys.argv[1])
path.write_bytes(base64.b64decode(data))
PYCONSOLE
  fi

  if [ -f "$INSTALL_DIR/coded-public-console.py" ]; then
    chmod +x "$INSTALL_DIR/coded-public-console.py" 2>/dev/null || true
    return 0
  fi

  echo "ERROR: coded-public-console.py unavailable. Refusing to show raw dev analytics."
  echo "run.sh embedded console restore failed."
  exit 88
}


coded_ensure_public_console

coded_manifest_commit() {
  local dir="$1"
  local mf=""

  for mf in "$dir/release_manifest.json" "$dir/manifest.json" "$dir/coded-miner/release_manifest.json" "$dir/coded-miner/manifest.json"; do
    if [ -s "$mf" ]; then
      sed -nE 's/.*"commit"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$mf" | head -1
      return 0
    fi
  done

  find "$dir" -maxdepth 3 -type f \( -name "release_manifest.json" -o -name "manifest.json" \) 2>/dev/null | while read -r mf; do
    sed -nE 's/.*"commit"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$mf" | head -1
    break
  done
}

coded_m1091v51p_platform_asset_name() {
  local channel="${1:-latest}"
  case "${PLATFORM:-}" in
    macos-arm64)
      if [ "$channel" = "beta" ]; then
        printf '%s\n' "coded-miner-macos-arm64-beta-latest.tar.gz"
      else
        printf '%s\n' "coded-miner-macos-arm64-latest.tar.gz"
      fi
      ;;
    windows*|win*)
      if [ "$channel" = "beta" ]; then
        printf '%s\n' "coded-miner-windows-amd64-beta-latest.tar.gz"
      else
        printf '%s\n' "coded-miner-windows-amd64-latest.tar.gz"
      fi
      ;;
    *)
      if [ "$channel" = "beta" ]; then
        printf '%s\n' "coded-miner-beta-latest.tar.gz"
      else
        printf '%s\n' "coded-miner-latest.tar.gz"
      fi
      ;;
  esac
}

coded_m1091v51p_effective_release_line() {
  local pool status_json wants_beta

  pool="${CODED_POOL_API_URL:-${POOL_API_URL:-http://178.104.150.57:4000}}"
  wants_beta=0

  case "${CODED_BETA_REQUESTED:-${CODED_BETA:-${BETA:-}}}" in
    1|yes|YES|true|TRUE|beta|BETA) wants_beta=1 ;;
  esac

  status_json="$(curl -fsSL --connect-timeout 5 --max-time 15 "${pool%/}/admin/release/channel-status" 2>/dev/null || true)"

  if [ -z "$status_json" ]; then
    printf '%s|%s|%s|%s|%s\n' \
      "${CODED_RELEASE_CHANNEL:-latest}" \
      "${CODED_RELEASE_VERSION:-${RELEASE_VERSION:-}}" \
      "${CODED_RELEASE_COMMIT:-${GIT_COMMIT:-}}" \
      "${CODED_RELEASE_ASSET_NAME:-}" \
      "${CODED_RELEASE_DOWNLOAD_URL:-${ASSET_URL:-}}"
    return 0
  fi

  STATUS_JSON="$status_json" python3 -c '
import json, os, sys

wants_beta = sys.argv[1] == "1"
platform = sys.argv[2] or ""
repo = "https://github.com/CodedOnQubic/coded-miner-release/releases"

try:
    d = json.loads(os.environ.get("STATUS_JSON") or "{}")
except Exception:
    d = {}

latest = d.get("public_latest") or {}
beta = d.get("beta") or {}

def asset_for(channel):
    if platform == "macos-arm64":
        return "coded-miner-macos-arm64-beta-latest.tar.gz" if channel == "beta" else "coded-miner-macos-arm64-latest.tar.gz"
    if platform.startswith("windows") or platform.startswith("win"):
        return "coded-miner-windows-amd64-beta-latest.tar.gz" if channel == "beta" else "coded-miner-windows-amd64-latest.tar.gz"
    return "coded-miner-beta-latest.tar.gz" if channel == "beta" else "coded-miner-latest.tar.gz"

if wants_beta and beta.get("version") and beta.get("commit"):
    channel = "beta"
    version = str(beta.get("version") or "")
    commit = str(beta.get("commit") or "")
    asset = asset_for(channel)
    url = repo + "/download/" + version + "/" + asset
    print("|".join([channel, version, commit, asset, url]))
    sys.exit(0)

channel = "latest"
version = str(latest.get("version") or "")
commit = str(latest.get("commit") or "")
asset = asset_for(channel)
url = repo + "/download/" + version + "/" + asset if version else repo + "/latest/download/" + asset
print("|".join([channel, version, commit, asset, url]))
' "$wants_beta" "${PLATFORM:-}"
}

coded_m1091v51p_kill_current_public_children() {
  local pid pf

  for pf in "$PID_DIR/miner.pid" "$PID_DIR/analytics.pid"; do
    [ -f "$pf" ] || continue
    pid="$(cat "$pf" 2>/dev/null || true)"
    [ -n "$pid" ] || continue
    kill "$pid" 2>/dev/null || true
  done

  sleep 1

  for pf in "$PID_DIR/miner.pid" "$PID_DIR/analytics.pid"; do
    [ -f "$pf" ] || continue
    pid="$(cat "$pf" 2>/dev/null || true)"
    [ -n "$pid" ] || continue
    kill -9 "$pid" 2>/dev/null || true
  done
}

coded_m1091v55b_quiet_stop_public_children() {
  # M1091V55B: parent-owned child shutdown. This avoids interactive shell
  # "Terminated: 15 env ..." job notices during public autoupdate transitions.
  local pid seen pids

  pids=""
  for pid in "${MINER_PID:-}" "${ANALYTICS_PID:-}" "$(cat "$PID_DIR/miner.pid" 2>/dev/null || true)" "$(cat "$PID_DIR/analytics.pid" 2>/dev/null || true)"; do
    [ -n "$pid" ] || continue
    seen=0
    for p in $pids; do [ "$p" = "$pid" ] && seen=1; done
    [ "$seen" = "1" ] && continue
    pids="$pids $pid"
  done

  for pid in $pids; do
    kill "$pid" 2>/dev/null || true
  done

  sleep 1

  for pid in $pids; do
    kill -0 "$pid" 2>/dev/null || continue
    kill -9 "$pid" 2>/dev/null || true
  done

  for pid in $pids; do
    wait "$pid" 2>/dev/null || true
  done
}

# M1091V55F_PUBLIC_SIGNAL_TREE_CLEANUP_BEGIN
#
# A foreground public run.sh owns its child processes.
#
# SIGINT  = Ctrl+C
# SIGHUP  = terminal/window closed
# SIGTERM = service/supervisor stop
#
# All three must terminate miner + analytics sidecar and the
# runner-owned console/autoupdate/restart-watcher children.
#
# Bash 3.2 compatible: shared macOS/Linux public one-liner.
#
CODED_V55F_CLEANUP_ACTIVE=0


coded_m1091v55f_valid_pid() {
  case "${1:-}" in
    ""|*[!0-9]*|0|1)
      return 1
      ;;
  esac

  [ "$1" != "$$" ]
}


coded_m1091v55f_stop_child() {
  local pid="${1:-}"
  local label="${2:-child}"
  local tick=0

  coded_m1091v55f_valid_pid "$pid" ||
    return 0

  if ! kill -0 "$pid" 2>/dev/null; then
    return 0
  fi

  coded_m1091v54k_debug \
    "[M1091V55F] stopping ${label} pid=${pid}"

  kill -TERM "$pid" 2>/dev/null || true

  tick=0

  while kill -0 "$pid" 2>/dev/null
  do
    if [ "$tick" -ge 20 ]; then
      break
    fi

    sleep 0.1
    tick=$((tick + 1))
  done

  if kill -0 "$pid" 2>/dev/null; then
    kill -KILL "$pid" 2>/dev/null || true
  fi

  wait "$pid" 2>/dev/null || true
}


coded_m1091v55f_clear_pid_file() {
  local file="${1:-}"
  local expected="${2:-}"
  local current=""

  coded_m1091v55f_valid_pid "$expected" ||
    return 0

  [ -f "$file" ] ||
    return 0

  current="$(
    tr -cd '0-9' < "$file" 2>/dev/null ||
    true
  )"

  if [ "$current" = "$expected" ]; then
    rm -f "$file" 2>/dev/null || true
  fi
}


coded_m1091v55f_cleanup_children() {
  local reason="${1:-runner_exit}"

  if [ "${CODED_V55F_CLEANUP_ACTIVE:-0}" = "1" ]; then
    return 0
  fi

  CODED_V55F_CLEANUP_ACTIVE=1

  coded_m1091v54k_debug \
    "[M1091V55F] child-tree cleanup reason=${reason}"

  # Disable anything capable of initiating another restart first.
  coded_m1091v55f_stop_child \
    "${RESTART_WATCH_PID:-}" \
    "restart-watcher"

  coded_m1091v55f_stop_child \
    "${UPDATE_PID:-}" \
    "autoupdate"

  # Then close UI and runtime children.
  coded_m1091v55f_stop_child \
    "${CONSOLE_PID:-}" \
    "public-console"

  coded_m1091v55f_stop_child \
    "${MINER_PID:-}" \
    "miner"

  coded_m1091v55f_stop_child \
    "${ANALYTICS_PID:-}" \
    "analytics-sidecar"

  # M1091V55F/R2:
  # The stderr process-substitution filter is also runner-owned.
  #
  # Restore stderr to FD 3 first. This closes the pipe writer in
  # this shell, allowing the direct awk process to receive EOF.
  #
  # If it does not exit promptly, the normal child stop helper
  # provides TERM -> KILL fallback.
  if coded_m1091v55f_valid_pid "${CODED_V55E_STDERR_FILTER_PID:-}"; then
    if { : >&3; } 2>/dev/null; then
      exec 2>&3 3>&-
    fi

    coded_m1091v55f_stop_child \
      "${CODED_V55E_STDERR_FILTER_PID:-}" \
      "stderr-filter"

    unset CODED_V55E_STDERR_FILTER_PID
    unset CODED_V55E_STDERR_FILTERED
  fi

  if [ -n "${PID_DIR:-}" ]; then
    coded_m1091v55f_clear_pid_file \
      "$PID_DIR/miner.pid" \
      "${MINER_PID:-}"

    coded_m1091v55f_clear_pid_file \
      "$PID_DIR/analytics.pid" \
      "${ANALYTICS_PID:-}"

    coded_m1091v55f_clear_pid_file \
      "$PID_DIR/autoupdate.pid" \
      "${UPDATE_PID:-}"

    coded_m1091v55f_clear_pid_file \
      "$PID_DIR/restart-watch.pid" \
      "${RESTART_WATCH_PID:-}"
  fi
}


coded_m1091v55f_signal_exit() {
  local signal_name="$1"
  local exit_code="$2"

  trap - HUP INT TERM EXIT

  coded_m1091v55f_cleanup_children \
    "signal_${signal_name}"

  exit "$exit_code"
}


coded_m1091v55f_exit_cleanup() {
  local exit_code="$?"

  trap - EXIT

  coded_m1091v55f_cleanup_children \
    "runner_exit_${exit_code}"

  exit "$exit_code"
}


coded_m1091v55f_install_signal_traps() {
  trap \
    'coded_m1091v55f_signal_exit HUP 129' \
    HUP

  trap \
    'coded_m1091v55f_signal_exit INT 130' \
    INT

  trap \
    'coded_m1091v55f_signal_exit TERM 143' \
    TERM

  trap \
    'coded_m1091v55f_exit_cleanup' \
    EXIT
}
# M1091V55F_PUBLIC_SIGNAL_TREE_CLEANUP_END

coded_public_autoupdate_start() {
  # M1091V51P_FINAL_CHANNEL_AWARE_PUBLIC_AUTOUPDATE
  # M1091V51Q_PUBLIC_AUTOUPDATE_SINGLE_LOOP_CLEANUP
  local old_update_pid initial_commit initial_channel key_file

  key_file="$STATE_DIR/release.key"

  old_update_pid="$(cat "$PID_DIR/autoupdate.pid" 2>/dev/null || true)"
  if [ -n "$old_update_pid" ] && kill -0 "$old_update_pid" 2>/dev/null; then
    coded_m1091v54k_debug "[M1091V51Q] stopping old autoupdate pid=$old_update_pid"
    kill "$old_update_pid" 2>/dev/null || true
    sleep 1
    kill -9 "$old_update_pid" 2>/dev/null || true
  fi
  rm -f "$PID_DIR/autoupdate.pid" 2>/dev/null || true

  initial_commit="$(coded_manifest_commit "$INSTALL_DIR" | head -1)"
  initial_channel="${CODED_RELEASE_CHANNEL:-latest}"
  if [ -n "$initial_commit" ]; then
    printf '%s:%s\n' "$initial_channel" "$initial_commit" > "$key_file" 2>/dev/null || true
  fi

  case "${CODED_DISABLE_PUBLIC_AUTOUPDATE:-0}" in
    1|yes|YES|true|TRUE) return 0 ;;
  esac

  (
    log_file="$LOG_DIR/public-autoupdate.log"
    key_file="$STATE_DIR/release.key"

    while true; do
      sleep "$CODED_PUBLIC_UPDATE_SEC"

      cur_commit="$(coded_manifest_commit "$INSTALL_DIR" | head -1)"
      cur_channel="${CODED_RELEASE_CHANNEL:-latest}"
      cur_key="$(cat "$key_file" 2>/dev/null || true)"
      [ -n "$cur_key" ] || cur_key="${cur_channel}:${cur_commit:-unknown}"

      effective_line="$(coded_m1091v51p_effective_release_line || true)"
      IFS='|' read -r effective_channel effective_version effective_commit effective_asset effective_url <<EOF_M1091V51P
$effective_line
EOF_M1091V51P

      [ -n "$effective_channel" ] || effective_channel="${CODED_RELEASE_CHANNEL:-latest}"
      [ -n "$effective_commit" ] || effective_commit="${CODED_RELEASE_COMMIT:-$cur_commit}"
      [ -n "$effective_asset" ] || effective_asset="$(coded_m1091v51p_platform_asset_name "$effective_channel")"

      new_key="${effective_channel}:${effective_commit:-unknown}"

      if [ "$new_key" = "$cur_key" ] && [ -n "$cur_commit" ] && [ "$effective_commit" = "$cur_commit" ]; then
        coded_m1091v54k_debug "[M1091V33A_PUBLIC_RUNSH_AUTOUPDATE_300S] already_latest commit=$cur_commit key=$cur_key at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log_file"
        continue
      fi

      tmp_dir="$STATE_DIR/autoupdate.$$"
      tar_file="$STATE_DIR/autoupdate.tar.gz"
      rm -rf "$tmp_dir"
      mkdir -p "$tmp_dir"

      DOWNLOAD_OK=0
      for u in ${effective_url:-} ${CODED_RELEASE_DOWNLOAD_URL:-} ${ASSET_URLS:-$ASSET_URL}; do
        [ -n "$u" ] || continue
        if curl -fsSL --retry 2 "$u" -o "$tar_file" 2>>"$log_file"; then
          DOWNLOAD_OK=1
          break
        fi
      done

      if [ "$DOWNLOAD_OK" != "1" ]; then
        coded_m1091v54k_debug "[M1091V33A_PUBLIC_RUNSH_AUTOUPDATE_300S] download_failed keep_current cur=$cur_commit key=$cur_key target=$new_key at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log_file"
        rm -rf "$tmp_dir"
        continue
      fi

      if ! tar -xzf "$tar_file" -C "$tmp_dir" 2>>"$log_file"; then
        coded_m1091v54k_debug "[M1091V33A_PUBLIC_RUNSH_AUTOUPDATE_300S] extract_failed keep_current cur=$cur_commit key=$cur_key target=$new_key at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log_file"
        rm -rf "$tmp_dir"
        continue
      fi

      root="$tmp_dir"
      if [ -d "$tmp_dir/coded-miner" ]; then
        root="$tmp_dir/coded-miner"
      fi

      new_commit="$(coded_manifest_commit "$root" | head -1)"

      if [ -z "$new_commit" ]; then
        coded_m1091v54k_debug "[M1091V33A_PUBLIC_RUNSH_AUTOUPDATE_300S] new_commit_missing keep_current cur=$cur_commit key=$cur_key target=$new_key at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log_file"
        rm -rf "$tmp_dir"
        continue
      fi

      # Trust manifest commit over channel-status if asset resolves correctly.
      new_key="${effective_channel}:${new_commit}"

      if [ "$new_key" = "$cur_key" ] && [ "$new_commit" = "$cur_commit" ]; then
        coded_m1091v54k_debug "[M1091V33A_PUBLIC_RUNSH_AUTOUPDATE_300S] already_latest commit=$new_commit key=$new_key at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log_file"
        rm -rf "$tmp_dir"
        continue
      fi

      coded_m1091v54k_debug "[M1091V33A_PUBLIC_RUNSH_AUTOUPDATE_300S] update_available old=${cur_commit:-missing} new=$new_commit old_key=${cur_key:-missing} new_key=${new_key:-missing} restarting at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log_file"

      rm -rf "$INSTALL_DIR.next" "$INSTALL_DIR.prev"
      mkdir -p "$INSTALL_DIR.next"
      cp -R "$root"/. "$INSTALL_DIR.next"/
      chmod +x "$INSTALL_DIR.next"/* 2>/dev/null || true

      if [ -d "$INSTALL_DIR" ]; then
        mv "$INSTALL_DIR" "$INSTALL_DIR.prev" 2>/dev/null || rm -rf "$INSTALL_DIR"
      fi
      mv "$INSTALL_DIR.next" "$INSTALL_DIR"

      printf '%s\n' "$new_key" > "$key_file" 2>/dev/null || true
      touch "$STATE_DIR/restart.required" 2>/dev/null || true
      printf '%s\n' "$new_key" > "$PID_DIR/update.request" 2>/dev/null || true

      rm -rf "$tmp_dir"

      # M1091V55B: do not kill child processes from the background updater.
      # The parent runner notices update.request/restart.required, shows the
      # public loader, stops children quietly, and then execs the fresh runner.
      break
    done
  ) &

  UPDATE_PID="$!"
  echo "$UPDATE_PID" > "$PID_DIR/autoupdate.pid" 2>/dev/null || true
}


pick_exe() {
  case "$BACKEND" in
    avx512)
      for f in coded-miner-avx512-safe coded-miner-avx512 coded-miner; do
        [ -x "$INSTALL_DIR/$f" ] && echo "$INSTALL_DIR/$f" && return 0
      done
      ;;
    avx2)
      for f in coded-miner-avx2 coded-miner; do
        [ -x "$INSTALL_DIR/$f" ] && echo "$INSTALL_DIR/$f" && return 0
      done
      ;;
    scalar)
      for f in coded-miner-scalar coded-miner; do
        [ -x "$INSTALL_DIR/$f" ] && echo "$INSTALL_DIR/$f" && return 0
      done
      ;;
    auto|*)
      if [ "$PLATFORM" = "linux-amd64" ]; then
        if grep -qw avx512f /proc/cpuinfo 2>/dev/null && [ -x "$INSTALL_DIR/coded-miner-avx512-safe" ]; then echo "$INSTALL_DIR/coded-miner-avx512-safe"; return 0; fi
        if grep -qw avx2 /proc/cpuinfo 2>/dev/null && [ -x "$INSTALL_DIR/coded-miner-avx2" ]; then echo "$INSTALL_DIR/coded-miner-avx2"; return 0; fi
      fi
      for f in coded-miner coded-miner-scalar coded-miner-avx2 coded-miner-avx512-safe; do
        [ -x "$INSTALL_DIR/$f" ] && echo "$INSTALL_DIR/$f" && return 0
      done
      ;;
  esac
  return 1
}

MINER_EXE="$(pick_exe || true)"
if [ -z "$MINER_EXE" ]; then
  echo "ERROR: no CODED miner executable found in package"
  find "$INSTALL_DIR" -maxdepth 2 -type f | sort
  exit 1
fi

SELECTED_BACKEND="$BACKEND"
case "$(basename "$MINER_EXE")" in
  *avx512*) SELECTED_BACKEND="avx512" ;;
  *avx2*) SELECTED_BACKEND="avx2" ;;
  *scalar*) SELECTED_BACKEND="scalar" ;;
  coded-miner) [ "$PLATFORM" = "macos-arm64" ] && SELECTED_BACKEND="${CODED_BACKEND:-arm-neon}" ;;
esac

# M1091V54B: On macOS ARM the runtime path is NEON even if the shipped
# executable has a scalar-looking filename. The frontend should not classify it
# as x86 scalar.
if [ "$PLATFORM" = "macos-arm64" ]; then
  SELECTED_BACKEND="${CODED_MAC_ARM_BACKEND_LABEL:-arm-neon}"
  export CODED_BACKEND="$SELECTED_BACKEND"
  export CODED_KERNEL_BACKEND="$SELECTED_BACKEND"
  export CODED_ARM_NEON_KERNEL="${CODED_ARM_NEON_KERNEL:-compat32}"
fi

if [ ! -f "$INSTALL_DIR/coded-runtime-sidecar.py" ]; then
  echo "ERROR: coded-runtime-sidecar.py missing in package"
  find "$INSTALL_DIR" -maxdepth 2 -type f | sort
  exit 1
fi

# M1091V55F: install terminal traps before first runtime child starts.
coded_m1091v55f_install_signal_traps

coded_ui_loader 72 "Starting neural network training"
env \
  CODED_PLATFORM="$PLATFORM" \
  CODED_BACKEND_PLATFORM="$PLATFORM" \
  CODED_KERNEL_BACKEND="$SELECTED_BACKEND" \
  CODED_BACKEND="$SELECTED_BACKEND" \
  CODED_POOL="$POOL" \
  CODED_WALLET="$WALLET" \
  CODED_WORKER="$WORKER_SAFE" \
  CODED_WORKER_NAME="$WORKER_SAFE" \
  CODED_RIG_ID="$WORKER_SAFE" \
  CODED_RUN_ID="$RUN_ID" \
  CODED_THREADS="$THREADS" \
  CODED_THRESHOLD="$THRESHOLD" \
  CODED_ANALYTICS=YES \
  CODED_ANALYTICS_ENABLED=1 \
  CODED_LOG_FILE="$RUN_LOG" \
  "$MINER_EXE" \
    --pool "$POOL" \
    --wallet "$WALLET" \
    --worker "$WORKER_SAFE" \
    --threads "$THREADS" \
  >> "$RUN_LOG" 2>&1 &
MINER_PID=$!
echo "$MINER_PID" > "$PID_DIR/miner.pid"

sleep 3

coded_ui_loader 82 "Starting analytics heartbeat"
nohup env \
  PYTHONPATH="$INSTALL_DIR" \
  CODED_POOL_API_BASE="$API_ROOT" \
  RIG_ID="$WORKER_SAFE" \
  CODED_RIG_ID="$WORKER_SAFE" \
  DEVICE_ID="$WORKER_SAFE" \
  CODED_DEVICE_ID="$WORKER_SAFE" \
  WORKER="$WORKER_SAFE" \
  WORKER_NAME="$WORKER_SAFE" \
  CODED_WORKER="$WORKER_SAFE" \
  CODED_WORKER_NAME="$WORKER_SAFE" \
  RUN_ID="$RUN_ID" \
  CODED_RUN_ID="$RUN_ID" \
  RUN_LOG="$RUN_LOG" \
  CODED_RUN_LOG="$RUN_LOG" \
  CODED_PLATFORM="$PLATFORM" \
  CODED_BACKEND_PLATFORM="$PLATFORM" \
  CODED_BACKEND="$SELECTED_BACKEND" \
  CODED_KERNEL_BACKEND="$SELECTED_BACKEND" \
  CODED_ARM_NEON_KERNEL="${CODED_ARM_NEON_KERNEL:-compat32}" \
  CODED_RUN_ID="$RUN_ID" \
  CODED_RIG_ID="$WORKER_SAFE" \
  CODED_WORKER="$WORKER_SAFE" \
  CODED_WORKER_NAME="$WORKER_SAFE" \
  CODED_THREADS="$THREADS" \
  CODED_THRESHOLD="$THRESHOLD" \
  CODED_ANALYTICS_LOG="$RUN_LOG" \
  THRESHOLD="$THRESHOLD" \
  CODED_THRESHOLD="$THRESHOLD" \
  THREADS="$THREADS" \
  CODED_THREADS="$THREADS" \
  CODED_PLATFORM="$PLATFORM" \
  CODED_BACKEND_PLATFORM="$PLATFORM" \
  CODED_KERNEL_BACKEND="$SELECTED_BACKEND" \
  CODED_BACKEND="$SELECTED_BACKEND" \
  CODED_ANALYTICS=YES \
  ANALYTICS=YES \
  python3 "$INSTALL_DIR/coded-runtime-sidecar.py" \
  < /dev/null >> "$ANALYTICS_LOG" 2>&1 &
ANALYTICS_PID=$!
echo "$ANALYTICS_PID" > "$PID_DIR/analytics.pid"

coded_public_autoupdate_start

coded_ui_warmup "$CODED_PUBLIC_BOOT_SEC"
coded_ui_loader 100 "Neural network training online"
coded_ui_loader_finish


# M1091V51R_EXEC_RESTART_REQUIRED_AFTER_AUTOUPDATE
coded_m1091v51r_restart_if_required() {
  local reason

  if [ ! -f "$STATE_DIR/restart.required" ]; then
    return 0
  fi

  reason="$(cat "$STATE_DIR/restart.required" 2>/dev/null || true)"
  rm -f "$STATE_DIR/restart.required" 2>/dev/null || true

  coded_m1091v54k_debug "[M1091V51R] restart.required detected reason=${reason:-autoupdate}"

  coded_m1091v55e_stop_console_quiet
  coded_m1091v54k_public_restart_loader
  coded_m1091v55b_quiet_stop_public_children
  coded_m1091v53a_exec_fresh_runsh
}


# M1091V51S_PARENT_SIGNAL_RESTART_WATCHER
coded_m1091v51s_exec_restart() {
  local reason

  reason="$(cat "$STATE_DIR/restart.required" 2>/dev/null || true)"
  rm -f "$STATE_DIR/restart.required" 2>/dev/null || true

  coded_m1091v54k_debug "[M1091V51S] parent restart signal received reason=${reason:-autoupdate}"

  coded_m1091v55e_stop_console_quiet
  coded_m1091v54k_public_restart_loader
  coded_m1091v55b_quiet_stop_public_children
  coded_m1091v53a_exec_fresh_runsh
}

coded_m1091v51s_start_restart_watcher() {
  local parent_pid old_watch_pid

  parent_pid="$$"

  old_watch_pid="$(cat "$PID_DIR/restart-watch.pid" 2>/dev/null || true)"
  if [ -n "$old_watch_pid" ] && kill -0 "$old_watch_pid" 2>/dev/null; then
    coded_m1091v54k_debug "[M1091V51S] stopping old restart watcher pid=$old_watch_pid"
    kill "$old_watch_pid" 2>/dev/null || true
    sleep 1
    kill -9 "$old_watch_pid" 2>/dev/null || true
  fi
  rm -f "$PID_DIR/restart-watch.pid" 2>/dev/null || true

  trap 'coded_m1091v51s_exec_restart' USR1

  (
    while true; do
      sleep 2
      if [ -f "$STATE_DIR/restart.required" ]; then
        kill -USR1 "$parent_pid" 2>/dev/null || true
        exit 0
      fi
    done
  ) &

  RESTART_WATCH_PID="$!"
  echo "$RESTART_WATCH_PID" > "$PID_DIR/restart-watch.pid" 2>/dev/null || true
}

coded_m1091v51s_start_restart_watcher
# M1091V32A_PUBLIC_RUNSH_CONSOLE
# Visible terminal uses coded-public-console.py.
# Raw miner/analytics output remains in RUN_LOG for Universal Analytics.
CONSOLE_RC=0

if command -v python3 >/dev/null 2>&1 && [ -f "$INSTALL_DIR/coded-public-console.py" ]; then
  CODED_WORKER_NAME="$WORKER_SAFE" \
  CODED_WORKER="$WORKER_SAFE" \
  CODED_RIG_ID="$WORKER_SAFE" \
  CODED_WALLET="$WALLET" \
  CODED_THREADS="$THREADS" \
  CODED_SELECTED_BACKEND="$SELECTED_BACKEND" \
  CODED_KERNEL_BACKEND="$SELECTED_BACKEND" \
  CODED_BACKEND="$SELECTED_BACKEND" \
  CODED_PLATFORM="$PLATFORM" \
  CODED_PUBLIC_BRAND_EVERY="${CODED_PUBLIC_BRAND_EVERY:-9}" \
  CODED_PUBLIC_LINE_SEC="${CODED_PUBLIC_LINE_SEC:-1}" \
  python3 "$INSTALL_DIR/coded-public-console.py" "$RUN_LOG" "$MINER_PID" &
  CONSOLE_PID="$!"

  while kill -0 "$CONSOLE_PID" 2>/dev/null; do
    if [ -f "$STATE_DIR/restart.required" ] || [ -s "$PID_DIR/update.request" ]; then
      rm -f "$STATE_DIR/restart.required" "$PID_DIR/update.request" 2>/dev/null || true

      coded_m1091v55e_stop_console_quiet
      coded_m1091v54k_public_restart_loader
      coded_m1091v55b_quiet_stop_public_children

      if [ -n "${UPDATE_PID:-}" ]; then
        kill "$UPDATE_PID" 2>/dev/null || true
        wait "$UPDATE_PID" 2>/dev/null || true
      fi

      coded_m1091v53a_exec_fresh_runsh
    fi
    sleep 1
  done

  wait "$CONSOLE_PID" 2>/dev/null
  CONSOLE_RC="$?"
else
  echo "ERROR: coded-public-console.py unavailable. Raw dev analytics will not be shown."
  echo "RUN_LOG is still available internally at: $RUN_LOG"
  exit 88
fi

# M1091V55F:
# Console completion ends this foreground runner ownership.
# Do not leave miner/sidecar behind and do not block forever.
coded_m1091v55f_cleanup_children "console_exit"

if [ -s "$PID_DIR/update.request" ]; then
  rm -f "$PID_DIR/update.request" 2>/dev/null || true

  export WALLET="$WALLET"
  export WORKER="$WORKER_SAFE"
  export BACKEND="$BACKEND"
  export THREADS="$THREADS"
  export POOL="$POOL"
  export API_ROOT="$API_ROOT"
  export CODED_PUBLIC_UPDATE_SEC="${CODED_PUBLIC_UPDATE_SEC:-60}"
  export CODED_BETA_REQUESTED="${CODED_BETA_REQUESTED:-0}"
  export CODED_PUBLIC_BRAND_EVERY="${CODED_PUBLIC_BRAND_EVERY:-9}"
  export CODED_PUBLIC_LINE_SEC="${CODED_PUBLIC_LINE_SEC:-1}"
  export CODED_PUBLIC_BOOT_STATUS="Updating CODED MINER"
  export CODED_PUBLIC_BOOT_SEC="${CODED_PUBLIC_BOOT_SEC:-10}"

  coded_ui_box '$0.01  IS  CODED'
  coded_ui_loader 12 "Updating CODED MINER"
  sleep 1
  coded_ui_loader 45 "Downloading latest CODED MINER"
  sleep 1
  coded_m1091v54k_public_restart_loader
  sleep 1
  coded_ui_loader 100 "Restarting neural network training"
  coded_ui_loader_finish

  coded_m1091v53a_exec_fresh_runsh
fi

# M1091V54B: If the autoupdater killed the miner/console with SIGTERM but the
# explicit update flag was already consumed or missed, do not drop the terminal
# back to the shell. Re-enter the public runner once and let channel-status
# choose beta/latest.
if [ "${CONSOLE_RC:-0}" = "143" ]; then
  coded_m1091v54k_debug "[M1091V54B] console exited by SIGTERM; attempting channel-safe runner restart"
  coded_m1091v55e_stop_console_quiet
  coded_m1091v54k_public_restart_loader
  coded_m1091v55b_quiet_stop_public_children
  coded_m1091v53a_exec_fresh_runsh
fi

exit "$CONSOLE_RC"
