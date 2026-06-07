#!/usr/bin/env bash
set -euo pipefail

# M10.99Z273T_PUBLIC_MAC_ARM_FLEET_RUNNER
# Public one-liner:
#   WALLET=YOUR_WALLET WORKER=my-mac bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"
#
# Optional builder Mac1:
#   BUILDER=1 WALLET=... WORKER=Oscar-Mac-ARM-Z273B-DEFAULT_ANALYTICS_M1098E_T321 bash -c "$(curl -fsSL .../run.sh)"

WORKER="${WORKER:-${CODED_WORKER_NAME:-my-mac}}"
WALLET="${WALLET:-${CODED_WALLET:-}}"
BUILDER="${BUILDER:-${CODED_ENABLE_BUILD_AGENT:-0}}"
AUTOUPDATE="${AUTOUPDATE:-YES}"

if [ -z "$WALLET" ]; then
  echo "ERROR: missing WALLET"
  echo "Usage:"
  echo '  WALLET=YOUR_WALLET WORKER=my-mac bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"'
  exit 2
fi

DEVICE_ID="${DEVICE_ID:-${CODED_DEVICE_ID:-macos-arm64:${WORKER}}}"
BASE_DIR="${CODED_MAC_BASE_DIR:-/tmp/coded-miner-macos-arm64}"
URL="${CODED_MAC_ARM_LATEST_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64.tar.gz}"
TMP="/tmp/coded-mac-arm-public-runner-${WORKER}"
mkdir -p "$TMP" "$BASE_DIR"

GREEN=$'\033[32m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'
RESET=$'\033[0m'

echo "${CYAN}"
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                 CODED PUBLIC MAC ARM FLEET RUNNER                ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo "${RESET}"
echo "DEVICE       $DEVICE_ID"
echo "WORKER       $WORKER"
echo "BUILDER      $BUILDER"
echo "AUTOUPDATE   $AUTOUPDATE"
echo "MODE         DEFAULT ANALYTICS"
echo

echo "${YELLOW}Downloading latest macOS ARM release...${RESET}"
curl -L --fail \
  -H "Cache-Control: no-cache" \
  -H "Pragma: no-cache" \
  -o "$TMP/latest.tar.gz" \
  "$URL"

rm -rf "$TMP/extract"
mkdir -p "$TMP/extract"
tar -xzf "$TMP/latest.tar.gz" -C "$TMP/extract"

if [ -d "$TMP/extract/coded-miner" ]; then
  cp -R "$TMP/extract/coded-miner/." "$BASE_DIR/"
else
  cp -R "$TMP/extract/." "$BASE_DIR/"
fi

chmod +x "$BASE_DIR/coded-miner" 2>/dev/null || true

# M10.99Z273U_PUBLIC_RUN_FETCH_RUNTIME_SCRIPTS
# Public ARM tarball may contain only binary + manifest + uploader.
# Fetch supervisor/console/build-agent directly from coded-miner branch so foreign Macs need no repo.
SCRIPT_BRANCH="${CODED_SCRIPT_BRANCH:-z242-arm-hotpath-contract-clean}"
SCRIPT_BASE="${CODED_SCRIPT_BASE:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner/${SCRIPT_BRANCH}}"

mkdir -p "$BASE_DIR/scripts/macos" "$BASE_DIR/scripts"

fetch_script_z273u() {
  local rel="$1"
  local out="$BASE_DIR/$rel"
  if [ -s "$out" ]; then
    chmod +x "$out" 2>/dev/null || true
    return 0
  fi

  echo "${YELLOW}Fetching runtime script $rel...${RESET}"
  curl -L --fail \
    -H "Cache-Control: no-cache" \
    -H "Pragma: no-cache" \
    -o "$out" \
    "$SCRIPT_BASE/$rel"

  chmod +x "$out" 2>/dev/null || true
}

fetch_script_z273u "scripts/macos/coded_mac_arm_supervisor_z273g.sh"
fetch_script_z273u "scripts/macos/coded_mac_arm_public_console_z273n.sh"
fetch_script_z273u "scripts/external_arm_build_agent_z265b.sh"

chmod +x "$BASE_DIR/scripts/macos/coded_mac_arm_supervisor_z273g.sh" 2>/dev/null || true
chmod +x "$BASE_DIR/scripts/macos/coded_mac_arm_public_console_z273n.sh" 2>/dev/null || true
chmod +x "$BASE_DIR/scripts/external_arm_build_agent_z265b.sh" 2>/dev/null || true

SUP="$BASE_DIR/scripts/macos/coded_mac_arm_supervisor_z273g.sh"
CONSOLE="$BASE_DIR/scripts/macos/coded_mac_arm_public_console_z273n.sh"

if [ ! -f "$SUP" ]; then
  echo "ERROR: supervisor missing in release package: $SUP"
  exit 3
fi

if [ ! -f "$CONSOLE" ]; then
  echo "ERROR: public console missing in release package: $CONSOLE"
  exit 4
fi

echo "${GREEN}Starting CODED default analytics worker...${RESET}"

pkill -f "coded_mac_arm_supervisor_z273g.sh.*${WORKER}" >/dev/null 2>&1 || true
pkill -f "coded_mac_arm_log_uploader.py.*${WORKER}" >/dev/null 2>&1 || true
sleep 1

CODED_WORKER_NAME="$WORKER" \
CODED_DEVICE_ID="$DEVICE_ID" \
CODED_WALLET="$WALLET" \
CODED_SELF_UPDATE_CHECK_SEC="${CODED_SELF_UPDATE_CHECK_SEC:-60}" \
CODED_SELF_UPDATE_ENABLED="$AUTOUPDATE" \
CODED_POOL_API="${CODED_POOL_API:-http://pool.codedonqubic.com:4000/fleet/devices/heartbeat}" \
CODED_POOL_API_ROOT="${CODED_POOL_API_ROOT:-http://pool.codedonqubic.com:4000}" \
CODED_ENABLE_BUILD_AGENT="$BUILDER" \
CODED_DISABLE_BUILD_AGENT="$([ "$BUILDER" = "1" ] && echo 0 || echo 1)" \
nohup "$SUP" > "/tmp/coded-mac-arm-supervisor-launch-${WORKER}.log" 2>&1 &

sleep 3

CODED_WORKER_NAME="$WORKER" \
CODED_DEVICE_ID="$DEVICE_ID" \
CODED_WALLET="$WALLET" \
CODED_SELF_UPDATE_ENABLED="$AUTOUPDATE" \
CODED_ENABLE_BUILD_AGENT="$BUILDER" \
"$CONSOLE"
