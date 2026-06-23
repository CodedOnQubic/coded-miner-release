#!/usr/bin/env bash
set -euo pipefail

# M1091U9_PUBLIC_RUNNER_DIRECT_STANDARD
# Official public macOS ARM runner:
# - downloads latest macOS ARM package
# - starts coded-miner directly
# - starts ANALYTICS sidecar directly
# - no legacy supervisor
# - no cockpit
# - no LaunchAgent
# - no hardcoded Oscar worker
# - no hardcoded router
# - RealScore / fullscore is mandatory

RESET="\033[0m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BOLD="\033[1m"

echo
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║              CODED PUBLIC MAC ARM REALSCORE RUNNER               ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo

if [ -z "${WALLET:-}" ] || [ "${WALLET:-}" = "DEINE_WALLET" ] || [ "${WALLET:-}" = "YOUR_WALLET" ]; then
  echo -e "${RED}ERROR: WALLET is required.${RESET}"
  echo
  echo "Example:"
  echo '  WALLET=YOUR_QUBIC_WALLET WORKER=my-mac bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"'
  exit 1
fi

WORKER="${WORKER:-${CODED_WORKER_NAME:-$(hostname | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9._-')}}"
if [ -z "$WORKER" ]; then
  WORKER="mac-arm"
fi

WORKER_SAFE="$(echo "$WORKER" | tr -cd 'A-Za-z0-9._-' | cut -c1-64)"
if [ -z "$WORKER_SAFE" ]; then
  WORKER_SAFE="mac-arm"
fi

DEVICE_ID="${DEVICE_ID:-${CODED_DEVICE_ID:-macos-arm64:${WORKER_SAFE}}}"
THREADS="${THREADS:-${CODED_THREADS:-1}}"
THRESHOLD="${THRESHOLD:-${CODED_THRESHOLD:-509}}"
POOL="${POOL:-${CODED_POOL:-pool.codedonqubic.com:7777}}"
API_ROOT="${CODED_POOL_API_BASE:-${API_ROOT:-http://pool.codedonqubic.com:4000}}"

URL="${CODED_MAC_ARM_LATEST_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64.tar.gz}"

BASE_DIR="${CODED_BASE_DIR:-/tmp/coded-miner-macos-arm64}"
TMP_DIR="${BASE_DIR}.download.$$"
TAR_FILE="/tmp/coded-miner-macos-arm64.$$.tar.gz"

STATE_ROOT="${HOME}/.coded-miner/mac-arm"
STATE_DIR="${STATE_ROOT}/${WORKER_SAFE}"
LOG_DIR="${STATE_DIR}/logs"
PID_DIR="${STATE_DIR}/pids"

mkdir -p "$LOG_DIR" "$PID_DIR"

RUN_ID="LIVE_${WORKER_SAFE}_ARM_REALSCORE_$(date -u +%Y%m%d_%H%M%S)"
RUN_LOG="${LOG_DIR}/${RUN_ID}.log"
ANALYTICS_LOG="${LOG_DIR}/ANALYTICS_${RUN_ID}.log"

echo "DEVICE       $DEVICE_ID"
echo "WORKER       $WORKER_SAFE"
echo "MODE         REALSCORE + ANALYTICS"
echo "PROFILE      DEFAULT_MINER_PROFILE"
echo "ROUTER       backend/default profile"
echo "THRESHOLD    $THRESHOLD"
echo "THREADS      $THREADS"
echo "POOL         $POOL"
echo "API          $API_ROOT"
echo

echo -e "${YELLOW}Downloading latest macOS ARM release...${RESET}"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

curl -fL "$URL" -o "$TAR_FILE"
tar -xzf "$TAR_FILE" -C "$TMP_DIR"

if [ ! -x "$TMP_DIR/coded-miner" ]; then
  chmod +x "$TMP_DIR/coded-miner" 2>/dev/null || true
fi

if [ ! -x "$TMP_DIR/coded-miner" ]; then
  echo -e "${RED}ERROR: coded-miner missing or not executable in release package.${RESET}"
  exit 1
fi

if [ ! -f "$TMP_DIR/coded-runtime-sidecar.py" ]; then
  echo -e "${RED}ERROR: coded-runtime-sidecar.py missing in release package.${RESET}"
  exit 1
fi

if [ ! -d "$TMP_DIR/ANALYTICS" ]; then
  echo -e "${RED}ERROR: ANALYTICS component missing in release package.${RESET}"
  exit 1
fi

echo -e "${YELLOW}Stopping stale local CODED runtime...${RESET}"

for pf in "$PID_DIR/miner.pid" "$PID_DIR/analytics.pid"; do
  if [ -s "$pf" ]; then
    pid="$(cat "$pf" 2>/dev/null || true)"
    if [ -n "$pid" ]; then
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$pf"
  fi
done

PIDS="$(ps ax -o pid=,command= \
  | grep -E "${BASE_DIR}|coded-runtime-sidecar.py|coded_mac_arm|Oscar-Mac|macos-arm64:${WORKER_SAFE}|--worker ${WORKER_SAFE}" \
  | grep -v grep \
  | awk '{print $1}' || true)"

if [ -n "$PIDS" ]; then
  echo "$PIDS" | xargs kill -9 2>/dev/null || true
fi

sleep 1

rm -rf "$BASE_DIR"
mv "$TMP_DIR" "$BASE_DIR"
rm -f "$TAR_FILE"

chmod +x "$BASE_DIR/coded-miner" 2>/dev/null || true
chmod +x "$BASE_DIR/coded-runtime-sidecar.py" 2>/dev/null || true

cat > "$STATE_DIR/current.env" <<EOF
export RUN_ID="$RUN_ID"
export RUN_LOG="$RUN_LOG"
export ANALYTICS_LOG="$ANALYTICS_LOG"
export DEVICE_ID="$DEVICE_ID"
export WORKER="$WORKER_SAFE"
export BASE_DIR="$BASE_DIR"
EOF

echo -e "${YELLOW}Starting CODED RealScore miner...${RESET}"

nohup env \
  CODED_ANALYTICS=YES \
  ANALYTICS=YES \
  RIG_ID="$DEVICE_ID" \
  CODED_RIG_ID="$DEVICE_ID" \
  DEVICE_ID="$DEVICE_ID" \
  CODED_DEVICE_ID="$DEVICE_ID" \
  WORKER="$WORKER_SAFE" \
  WORKER_NAME="$WORKER_SAFE" \
  CODED_WORKER_NAME="$WORKER_SAFE" \
  RUN_ID="$RUN_ID" \
  CODED_RUN_ID="$RUN_ID" \
  RUN_LOG="$RUN_LOG" \
  CODED_RUN_LOG="$RUN_LOG" \
  CODED_ANALYTICS_LOG="$RUN_LOG" \
  THRESHOLD="$THRESHOLD" \
  CODED_THRESHOLD="$THRESHOLD" \
  CODED_FAST_SHADOW_THRESHOLD="$THRESHOLD" \
  THREADS="$THREADS" \
  CODED_THREADS="$THREADS" \
  CODED_PLATFORM="macos-arm64" \
  CODED_BACKEND_PLATFORM="macos-arm64" \
  CODED_KERNEL_BACKEND="arm-portable-real" \
  CODED_BACKEND="arm-portable-real" \
  CODED_BACKEND_KIND="arm-neon" \
  CODED_BACKEND_SHORT="arm" \
  QATUM_SCORE_ENGINE_MODE="reference" \
  CODED_SCORE_ENGINE_MODE="qatum-reference" \
  CODED_FORCE_FULLSCORE=1 \
  CODED_FULLSCORE=1 \
  CODED_FULLSCORE_ALL_BACKENDS=1 \
  CODED_PREFILTER_DIFFICULTY=0 \
  CODED_FAST_SHADOW_GATE=1 \
  CODED_FAST_SHADOW_AUDIT_RATE=1 \
  CODED_FAST_SHADOW_SUMMARY_SEC=30 \
  CODED_HI_TIMING=1 \
  CODED_VERBOSE_HI=1 \
  CODED_REAL_SCORE_AUDIT_DEBUG=1 \
  CODED_SCORE_AUDIT_DEBUG=1 \
  CODED_REQUIRE_REAL_SCORE=1 \
  CODED_DISABLE_STUB_SCORE=1 \
  CODED_NO_STUB_SCORE=1 \
  CODED_DEFAULT_ANALYTICS_PROFILE="DEFAULT_MINER_PROFILE" \
  CODED_PROFILE_VERSION="M1091U9_PUBLIC_MAC_ARM_REALSCORE_DIRECT_STANDARD" \
  "$BASE_DIR/coded-miner" \
    --pool "$POOL" \
    --wallet "$WALLET" \
    --worker "$WORKER_SAFE" \
    --threads "$THREADS" \
  >> "$RUN_LOG" 2>&1 &

MINER_PID=$!
echo "$MINER_PID" > "$PID_DIR/miner.pid"

sleep 5

echo -e "${YELLOW}Starting CODED ANALYTICS sidecar...${RESET}"

nohup env \
  PYTHONPATH="$BASE_DIR" \
  CODED_POOL_API_BASE="$API_ROOT" \
  RIG_ID="$DEVICE_ID" \
  CODED_RIG_ID="$DEVICE_ID" \
  DEVICE_ID="$DEVICE_ID" \
  CODED_DEVICE_ID="$DEVICE_ID" \
  WORKER="$WORKER_SAFE" \
  WORKER_NAME="$WORKER_SAFE" \
  CODED_WORKER_NAME="$WORKER_SAFE" \
  RUN_ID="$RUN_ID" \
  CODED_RUN_ID="$RUN_ID" \
  RUN_LOG="$RUN_LOG" \
  CODED_RUN_LOG="$RUN_LOG" \
  CODED_ANALYTICS_LOG="$RUN_LOG" \
  THRESHOLD="$THRESHOLD" \
  CODED_THRESHOLD="$THRESHOLD" \
  CODED_FAST_SHADOW_THRESHOLD="$THRESHOLD" \
  THREADS="$THREADS" \
  CODED_THREADS="$THREADS" \
  CODED_PLATFORM="macos-arm64" \
  CODED_BACKEND_PLATFORM="macos-arm64" \
  CODED_KERNEL_BACKEND="arm-portable-real" \
  CODED_BACKEND="arm-portable-real" \
  CODED_ANALYTICS=YES \
  ANALYTICS=YES \
  python3 "$BASE_DIR/coded-runtime-sidecar.py" \
  >> "$ANALYTICS_LOG" 2>&1 &

ANALYTICS_PID=$!
echo "$ANALYTICS_PID" > "$PID_DIR/analytics.pid"

sleep 2

echo
echo -e "${GREEN}CODED macOS ARM RealScore worker started.${RESET}"
echo
echo "RUN_ID        $RUN_ID"
echo "MINER_PID     $MINER_PID"
echo "ANALYTICS_PID $ANALYTICS_PID"
echo "RUN_LOG       $RUN_LOG"
echo "ANALYTICS_LOG $ANALYTICS_LOG"
echo
echo "Check:"
echo "  source \"$STATE_DIR/current.env\""
echo "  tail -f \"\$RUN_LOG\""
echo
echo "Process:"
ps ax -o pid=,command= \
  | grep -E "coded-runtime-sidecar|coded-miner|--worker ${WORKER_SAFE}" \
  | grep -v grep || true
