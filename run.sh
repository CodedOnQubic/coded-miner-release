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

# M1091U6_PUBLIC_MAC_ARM_STANDARD_PROFILE_DEFAULT
# Public Mac ARM default:
# - RealScore + Fullscore + ANALYTICS
# - Standard miner profile
# - Router is NOT baked into release.
# - Backend/supervisor may change router later without new release.
THRESHOLD="${THRESHOLD:-509}"
THREADS="${THREADS:-1}"

# Empty by default = use current standard profile / backend default.
# Optional manual override:
#   ROUTER=M1098E MATRIX=... WALLET=... WORKER=mac2 bash -c "$(curl -fsSL .../run.sh)"
ROUTER="${ROUTER:-${CODED_PRIORITY_BUDGET_ROUTER:-}}"
MATRIX="${MATRIX:-${CODED_PRIORITY_BUDGET_MATRIX:-}}"

STANDARD_PROFILE="${STANDARD_PROFILE:-${CODED_STANDARD_PROFILE:-DEFAULT_MINER_PROFILE}}"
POOL="${POOL:-${CODED_POOL:-pool.codedonqubic.com:7777}}"

CODED_ARM_MODE="${CODED_ARM_MODE:-realscore}"
CODED_KERNEL_BACKEND="${CODED_KERNEL_BACKEND:-arm-portable-real}"
CODED_BACKEND="${CODED_BACKEND:-arm-portable-real}"
CODED_BACKEND_KIND="${CODED_BACKEND_KIND:-arm-neon}"
CODED_BACKEND_SHORT="${CODED_BACKEND_SHORT:-arm}"
QATUM_SCORE_ENGINE_MODE="${QATUM_SCORE_ENGINE_MODE:-reference}"
CODED_SCORE_ENGINE_MODE="${CODED_SCORE_ENGINE_MODE:-qatum-reference}"

CODED_FORCE_FULLSCORE="${CODED_FORCE_FULLSCORE:-1}"
CODED_FULLSCORE="${CODED_FULLSCORE:-1}"
CODED_FULLSCORE_ALL_BACKENDS="${CODED_FULLSCORE_ALL_BACKENDS:-1}"
CODED_PREFILTER_DIFFICULTY="${CODED_PREFILTER_DIFFICULTY:-0}"
CODED_FAST_SHADOW_GATE="${CODED_FAST_SHADOW_GATE:-1}"
CODED_FAST_SHADOW_AUDIT_RATE="${CODED_FAST_SHADOW_AUDIT_RATE:-1}"
CODED_FAST_SHADOW_SUMMARY_SEC="${CODED_FAST_SHADOW_SUMMARY_SEC:-30}"
CODED_HI_TIMING="${CODED_HI_TIMING:-1}"
CODED_VERBOSE_HI="${CODED_VERBOSE_HI:-1}"
CODED_REAL_SCORE_AUDIT_DEBUG="${CODED_REAL_SCORE_AUDIT_DEBUG:-1}"
CODED_SCORE_AUDIT_DEBUG="${CODED_SCORE_AUDIT_DEBUG:-1}"
CODED_REQUIRE_REAL_SCORE="${CODED_REQUIRE_REAL_SCORE:-1}"
CODED_DISABLE_STUB_SCORE="${CODED_DISABLE_STUB_SCORE:-1}"
CODED_NO_STUB_SCORE="${CODED_NO_STUB_SCORE:-1}"

CODED_DEFAULT_ANALYTICS_PROFILE="${CODED_DEFAULT_ANALYTICS_PROFILE:-$STANDARD_PROFILE}"
CODED_PROFILE_VERSION="${CODED_PROFILE_VERSION:-M1091U6_PUBLIC_MAC_ARM_STANDARD_PROFILE_DEFAULT}"

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
echo "MODE         REALSCORE + ANALYTICS"
echo "PROFILE      $CODED_DEFAULT_ANALYTICS_PROFILE"
if [ -n "$ROUTER" ]; then
  echo "ROUTER       $ROUTER"
else
  echo "ROUTER       backend/default profile"
fi
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
# M10.99Z273AD_PUBLIC_RELEASE_RUNTIME_BASE
SCRIPT_BASE="${CODED_SCRIPT_BASE:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main}"

mkdir -p "$BASE_DIR/scripts/macos" "$BASE_DIR/scripts"

fetch_script_z273u() {
  local rel="$1"
  local out="$BASE_DIR/$rel"
  if [ -s "$out" ]; then
    chmod +x "$out" 2>/dev/null || true
    return 0
  fi

  echo "${YELLOW}Fetching runtime script $rel...${RESET}"

  local urls=(
    "$SCRIPT_BASE/$rel"
    "https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/$rel"
    "https://raw.githubusercontent.com/CodedOnQubic/coded-miner/z242-arm-hotpath-contract-clean/$rel"
    "https://raw.githubusercontent.com/CodedOnQubic/coded-miner/main/$rel"
  )

  local ok=0
  local u
  for u in "${urls[@]}"; do
    if curl -L --fail \
      -H "Cache-Control: no-cache" \
      -H "Pragma: no-cache" \
      -o "$out.tmp" \
      "$u"; then
      mv "$out.tmp" "$out"
      chmod +x "$out" 2>/dev/null || true
      ok=1
      echo "${GREEN}Fetched $rel${RESET}"
      break
    fi
    rm -f "$out.tmp"
  done

  if [ "$ok" != "1" ]; then
    echo "${YELLOW}WARN: could not fetch $rel; continuing if not critical${RESET}"
    return 0
  fi
}

fetch_script_z273u "scripts/macos/coded_mac_arm_supervisor_z273g.sh"
fetch_script_z273u "scripts/macos/coded_mac_arm_public_console_z273n.sh"
fetch_script_z273u "scripts/external_arm_build_agent_z265b.sh"
# M10.99Z273Y_RUN_FETCH_LAUNCHAGENT_INSTALLER
fetch_script_z273u "scripts/macos/install_coded_mac_arm_fleet_console_z273y.sh"

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

echo "${GREEN}Starting CODED standard RealScore worker...${RESET}"

# M1091U6_ROUTER_OVERRIDE_ONLY_IF_EXPLICIT
# Default: do not bake router into public release.
# If ROUTER/MATRIX are supplied, export them as manual overrides.
if [ -n "$ROUTER" ]; then
  export CODED_PRIORITY_BUDGET_ROUTER="$ROUTER"
  export CODED_PRIORITY_ROUTER="$ROUTER"
fi

if [ -n "$MATRIX" ]; then
  export CODED_PRIORITY_BUDGET_MATRIX="$MATRIX"
fi

export CODED_DEFAULT_ANALYTICS_PROFILE
export CODED_PROFILE_VERSION

# M1091U7_HARD_REPLACE_STALE_PUBLIC_MAC_RUNTIME
# Public one-liner must be idempotent:
# user can run it again and it replaces stale local runtime.
echo "${YELLOW}Stopping stale local CODED Mac ARM runtime if present...${RESET}"

pkill -9 -f "$BASE_DIR/scripts/macos/coded_mac_arm_supervisor_z273g.sh" >/dev/null 2>&1 || true
pkill -9 -f "coded_mac_arm_supervisor_z273g.sh" >/dev/null 2>&1 || true
pkill -9 -f "coded_mac_arm_log_uploader.py" >/dev/null 2>&1 || true
pkill -9 -f "coded-runtime-sidecar.py" >/dev/null 2>&1 || true
pkill -9 -f "$BASE_DIR/coded-miner" >/dev/null 2>&1 || true

sleep 2

CODED_WORKER_NAME="$WORKER" \
CODED_DEVICE_ID="$DEVICE_ID" \
CODED_RIG_ID="$DEVICE_ID" \
RIG_ID="$DEVICE_ID" \
WORKER_NAME="$WORKER" \
WORKER="$WORKER" \
CODED_WALLET="$WALLET" \
WALLET="$WALLET" \
THRESHOLD="$THRESHOLD" \
CODED_THRESHOLD="$THRESHOLD" \
CODED_FAST_SHADOW_THRESHOLD="$THRESHOLD" \
THREADS="$THREADS" \
CODED_THREADS="$THREADS" \
CODED_POOL="$POOL" \
CODED_PLATFORM="macos-arm64" \
CODED_BACKEND_PLATFORM="macos-arm64" \
CODED_KERNEL_BACKEND="$CODED_KERNEL_BACKEND" \
CODED_BACKEND="$CODED_BACKEND" \
CODED_BACKEND_KIND="$CODED_BACKEND_KIND" \
CODED_BACKEND_SHORT="$CODED_BACKEND_SHORT" \
QATUM_SCORE_ENGINE_MODE="$QATUM_SCORE_ENGINE_MODE" \
CODED_SCORE_ENGINE_MODE="$CODED_SCORE_ENGINE_MODE" \
CODED_FORCE_FULLSCORE="$CODED_FORCE_FULLSCORE" \
CODED_FULLSCORE="$CODED_FULLSCORE" \
CODED_FULLSCORE_ALL_BACKENDS="$CODED_FULLSCORE_ALL_BACKENDS" \
CODED_PREFILTER_DIFFICULTY="$CODED_PREFILTER_DIFFICULTY" \
CODED_FAST_SHADOW_GATE="$CODED_FAST_SHADOW_GATE" \
CODED_FAST_SHADOW_AUDIT_RATE="$CODED_FAST_SHADOW_AUDIT_RATE" \
CODED_FAST_SHADOW_SUMMARY_SEC="$CODED_FAST_SHADOW_SUMMARY_SEC" \
CODED_HI_TIMING="$CODED_HI_TIMING" \
CODED_VERBOSE_HI="$CODED_VERBOSE_HI" \
CODED_REAL_SCORE_AUDIT_DEBUG="$CODED_REAL_SCORE_AUDIT_DEBUG" \
CODED_SCORE_AUDIT_DEBUG="$CODED_SCORE_AUDIT_DEBUG" \
CODED_REQUIRE_REAL_SCORE="$CODED_REQUIRE_REAL_SCORE" \
CODED_DISABLE_STUB_SCORE="$CODED_DISABLE_STUB_SCORE" \
CODED_NO_STUB_SCORE="$CODED_NO_STUB_SCORE" \
CODED_DEFAULT_ANALYTICS_PROFILE="$CODED_DEFAULT_ANALYTICS_PROFILE" \
CODED_PROFILE_VERSION="$CODED_PROFILE_VERSION" \
CODED_ANALYTICS="YES" \
ANALYTICS="YES" \
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
CODED_RIG_ID="$DEVICE_ID" \
RIG_ID="$DEVICE_ID" \
WORKER_NAME="$WORKER" \
WORKER="$WORKER" \
CODED_WALLET="$WALLET" \
WALLET="$WALLET" \
THRESHOLD="$THRESHOLD" \
CODED_THRESHOLD="$THRESHOLD" \
CODED_FAST_SHADOW_THRESHOLD="$THRESHOLD" \
THREADS="$THREADS" \
CODED_THREADS="$THREADS" \
CODED_POOL="$POOL" \
CODED_PLATFORM="macos-arm64" \
CODED_BACKEND_PLATFORM="macos-arm64" \
CODED_KERNEL_BACKEND="$CODED_KERNEL_BACKEND" \
CODED_BACKEND="$CODED_BACKEND" \
CODED_BACKEND_KIND="$CODED_BACKEND_KIND" \
CODED_BACKEND_SHORT="$CODED_BACKEND_SHORT" \
QATUM_SCORE_ENGINE_MODE="$QATUM_SCORE_ENGINE_MODE" \
CODED_SCORE_ENGINE_MODE="$CODED_SCORE_ENGINE_MODE" \
CODED_FORCE_FULLSCORE="$CODED_FORCE_FULLSCORE" \
CODED_FULLSCORE="$CODED_FULLSCORE" \
CODED_FULLSCORE_ALL_BACKENDS="$CODED_FULLSCORE_ALL_BACKENDS" \
CODED_PREFILTER_DIFFICULTY="$CODED_PREFILTER_DIFFICULTY" \
CODED_FAST_SHADOW_GATE="$CODED_FAST_SHADOW_GATE" \
CODED_FAST_SHADOW_AUDIT_RATE="$CODED_FAST_SHADOW_AUDIT_RATE" \
CODED_FAST_SHADOW_SUMMARY_SEC="$CODED_FAST_SHADOW_SUMMARY_SEC" \
CODED_HI_TIMING="$CODED_HI_TIMING" \
CODED_VERBOSE_HI="$CODED_VERBOSE_HI" \
CODED_REAL_SCORE_AUDIT_DEBUG="$CODED_REAL_SCORE_AUDIT_DEBUG" \
CODED_SCORE_AUDIT_DEBUG="$CODED_SCORE_AUDIT_DEBUG" \
CODED_REQUIRE_REAL_SCORE="$CODED_REQUIRE_REAL_SCORE" \
CODED_DISABLE_STUB_SCORE="$CODED_DISABLE_STUB_SCORE" \
CODED_NO_STUB_SCORE="$CODED_NO_STUB_SCORE" \
CODED_DEFAULT_ANALYTICS_PROFILE="$CODED_DEFAULT_ANALYTICS_PROFILE" \
CODED_PROFILE_VERSION="$CODED_PROFILE_VERSION" \
CODED_ANALYTICS="YES" \
ANALYTICS="YES" \
CODED_SELF_UPDATE_ENABLED="$AUTOUPDATE" \
CODED_ENABLE_BUILD_AGENT="$BUILDER" \
"$CONSOLE"
