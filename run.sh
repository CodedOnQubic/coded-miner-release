#!/usr/bin/env bash

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
ASSET_URL="${CODED_LINUX_LATEST_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest.tar.gz}"

case "$OS/$ARCH" in
  darwin/arm64|darwin/aarch64)
    PLATFORM="macos-arm64"
      # M1091V32A3_PUBLIC_MAC_RELEASE_ASSET_FIRST
      # Prefer real button-published GitHub release assets.
      # Raw main tarballs are fallback only because they can lag behind release/latest.
      ASSET_URL="${CODED_MAC_ARM_LATEST_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64-latest.tar.gz}"
      ASSET_URLS="${CODED_MAC_ARM_LATEST_URLS:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64-latest.tar.gz https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64.tar.gz https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest-macos-arm64.tar.gz https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/coded-miner-macos-arm64-latest.tar.gz https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/coded-miner-macos-arm64.tar.gz}"
    ;;
  linux/x86_64|linux/amd64)
    PLATFORM="linux-amd64"
    ASSET_URL="${CODED_LINUX_LATEST_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest.tar.gz}"
    ASSET_URLS="${CODED_LINUX_LATEST_URLS:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest.tar.gz}"
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

mkdir -p "$LOG_DIR" "$PID_DIR" "$TMP_DIR"

RUN_ID="PUBLIC_${WORKER_SAFE}_${PLATFORM}_$(date -u +%Y%m%d_%H%M%S)"
RUN_LOG="$LOG_DIR/${RUN_ID}.log"
ANALYTICS_LOG="$LOG_DIR/ANALYTICS_${RUN_ID}.log"

echo "CODED public runner"
echo "Platform: $PLATFORM"
echo "Wallet:   $WALLET"
echo "Worker:   $WORKER_SAFE"
echo "Backend:  $BACKEND"
echo "Threads:  $THREADS"
echo "Pool:     $POOL"
echo "API:      $API_ROOT"
echo "Run ID:   $RUN_ID"
echo ""

# M1091V32E_STOP_ALL_PUBLIC_INSTANCES
# Public one-liner policy:
# A new public CODED start replaces all previous public CODED starts on this device.
# Scope is strictly CODED_BASE_DIR / ~/.coded-miner/public, so Hive/builders are not touched.
coded_stop_old_public_instances() {
  local base="${1:-}"
  [ -n "$base" ] || return 0

  echo "Stopping old CODED public runner processes on this device..."

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

echo "Downloading latest CODED package..."
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

DOWNLOAD_OK=0
for u in ${ASSET_URLS:-$ASSET_URL}; do
  echo "Trying asset: $u"
  if curl -fL "$u" -o "$TAR_FILE"; then
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

# M1091V32H_FORCE_PUBLIC_CONSOLE_NO_RAW_FALLBACK
# A bad/rebuilt asset must never expose raw dev analytics in the public terminal.
# If the package misses coded-public-console.py, fetch it directly from coded-miner.
coded_ensure_public_console() {
  if [ -f "$INSTALL_DIR/coded-public-console.py" ]; then
    chmod +x "$INSTALL_DIR/coded-public-console.py" 2>/dev/null || true
    return 0
  fi

  local console_url="${CODED_PUBLIC_CONSOLE_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner/m1091v6-clean-hive-autostart/release/hiveos/coded-miner/coded-public-console.py}"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 "$console_url" -o "$INSTALL_DIR/coded-public-console.py" 2>/dev/null || true
  fi

  if [ -f "$INSTALL_DIR/coded-public-console.py" ]; then
    chmod +x "$INSTALL_DIR/coded-public-console.py" 2>/dev/null || true
    return 0
  fi

  echo "ERROR: coded-public-console.py unavailable. Refusing to show raw dev analytics."
  echo "Fix release asset or CODED_PUBLIC_CONSOLE_URL."
  exit 88
}

coded_ensure_public_console

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

if [ ! -f "$INSTALL_DIR/coded-runtime-sidecar.py" ]; then
  echo "ERROR: coded-runtime-sidecar.py missing in package"
  find "$INSTALL_DIR" -maxdepth 2 -type f | sort
  exit 1
fi

echo "Starting CODED miner..."
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

echo "Starting CODED analytics sidecar..."
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

echo ""
echo "CODED public worker started."
echo "WORKER $WORKER_SAFE"
echo "BACKEND $SELECTED_BACKEND"
echo "THREADS $THREADS"
echo "MINER_PID $MINER_PID"
echo "ANALYTICS_PID $ANALYTICS_PID"
echo "RUN_LOG $RUN_LOG"
echo "ANALYTICS_LOG $ANALYTICS_LOG"
echo ""
echo "Public console:"
echo "  internal raw log: $RUN_LOG"
echo ""

# M1091V32A_PUBLIC_RUNSH_CONSOLE
# Visible terminal uses coded-public-console.py.
# Raw miner/analytics output remains in RUN_LOG for Universal Analytics.
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
  python3 "$INSTALL_DIR/coded-public-console.py" "$RUN_LOG" "$MINER_PID"
else
  echo "ERROR: coded-public-console.py unavailable. Raw dev analytics will not be shown."
  echo "RUN_LOG is still available internally at: $RUN_LOG"
  exit 88
fi
