#!/usr/bin/env bash
set -euo pipefail

# M1091V28_LINUX_MAC_PUBLIC_RUNNER_CANONICAL_ANALYTICS
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
    ASSET_URL="${CODED_MAC_ARM_LATEST_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64.tar.gz}"
    ;;
  linux/x86_64|linux/amd64)
    PLATFORM="linux-amd64"
    ASSET_URL="${CODED_LINUX_LATEST_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest.tar.gz}"
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

echo "Stopping old CODED public runner processes for worker $WORKER_SAFE..."
for pf in "$PID_DIR/miner.pid" "$PID_DIR/analytics.pid"; do
  if [ -s "$pf" ]; then
    kill -9 "$(cat "$pf" 2>/dev/null)" 2>/dev/null || true
    rm -f "$pf"
  fi
done

pkill -f "coded-runtime-sidecar.py.*${WORKER_SAFE}" 2>/dev/null || true
pkill -f "coded-miner.*--worker ${WORKER_SAFE}" 2>/dev/null || true
pkill -f "coded-miner-avx2.*--worker ${WORKER_SAFE}" 2>/dev/null || true
pkill -f "coded-miner-avx512.*--worker ${WORKER_SAFE}" 2>/dev/null || true
pkill -f "coded-miner-scalar.*--worker ${WORKER_SAFE}" 2>/dev/null || true

echo "Downloading latest CODED package..."
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
curl -fL "$ASSET_URL" -o "$TAR_FILE"
tar -xzf "$TAR_FILE" -C "$TMP_DIR"

ROOT="$TMP_DIR"
if [ -d "$TMP_DIR/coded-miner" ]; then
  ROOT="$TMP_DIR/coded-miner"
fi

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -R "$ROOT"/. "$INSTALL_DIR"/
chmod +x "$INSTALL_DIR"/* 2>/dev/null || true

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
  coded-miner) [ "$PLATFORM" = "macos-arm64" ] && SELECTED_BACKEND="arm-portable-real" ;;
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
    --threshold "$THRESHOLD" \
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
  >> "$ANALYTICS_LOG" 2>&1 &
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
echo "Tail log:"
echo "  tail -f '$RUN_LOG'"
echo ""
tail -n 40 -f "$RUN_LOG"
