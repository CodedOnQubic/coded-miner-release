#!/usr/bin/env bash
set -euo pipefail

# M1091U8_PUBLIC_SUPERVISOR_ENV_IS_SOURCE_OF_TRUTH
# Public one-liner ENV is the source of truth.
# Do not fall back to old baked Mac1/Oscar defaults.
WORKER="${CODED_WORKER_NAME:-${WORKER_NAME:-${WORKER:-my-mac}}}"
CODED_WORKER_NAME="$WORKER"
WORKER_NAME="$WORKER"

DEVICE_ID="${CODED_DEVICE_ID:-${DEVICE_ID:-macos-arm64:${WORKER}}}"
CODED_DEVICE_ID="$DEVICE_ID"
CODED_RIG_ID="${CODED_RIG_ID:-$DEVICE_ID}"
RIG_ID="${RIG_ID:-$DEVICE_ID}"

THRESHOLD="${CODED_THRESHOLD:-${THRESHOLD:-509}}"
CODED_THRESHOLD="$THRESHOLD"
CODED_FAST_SHADOW_THRESHOLD="${CODED_FAST_SHADOW_THRESHOLD:-$THRESHOLD}"

THREADS="${CODED_THREADS:-${THREADS:-1}}"
CODED_THREADS="$THREADS"

CODED_PLATFORM="${CODED_PLATFORM:-macos-arm64}"
CODED_BACKEND_PLATFORM="${CODED_BACKEND_PLATFORM:-macos-arm64}"
CODED_KERNEL_BACKEND="${CODED_KERNEL_BACKEND:-arm-portable-real}"
CODED_BACKEND="${CODED_BACKEND:-arm-portable-real}"
QATUM_SCORE_ENGINE_MODE="${QATUM_SCORE_ENGINE_MODE:-reference}"
CODED_SCORE_ENGINE_MODE="${CODED_SCORE_ENGINE_MODE:-qatum-reference}"

CODED_FORCE_FULLSCORE="${CODED_FORCE_FULLSCORE:-1}"
CODED_FULLSCORE="${CODED_FULLSCORE:-1}"
CODED_FULLSCORE_ALL_BACKENDS="${CODED_FULLSCORE_ALL_BACKENDS:-1}"
CODED_REQUIRE_REAL_SCORE="${CODED_REQUIRE_REAL_SCORE:-1}"
CODED_DISABLE_STUB_SCORE="${CODED_DISABLE_STUB_SCORE:-1}"
CODED_NO_STUB_SCORE="${CODED_NO_STUB_SCORE:-1}"
CODED_ANALYTICS="${CODED_ANALYTICS:-YES}"
ANALYTICS="${ANALYTICS:-YES}"

CODED_DEFAULT_ANALYTICS_PROFILE="${CODED_DEFAULT_ANALYTICS_PROFILE:-DEFAULT_MINER_PROFILE}"
CODED_PROFILE_VERSION="${CODED_PROFILE_VERSION:-M1091U8_PUBLIC_MAC_ARM_STANDARD_PROFILE_REALSCORE}"


# M10.99Z273M_MAC1_SUPERVISOR_SINGLETON_NO_SPAM
# One Mac1 supervisor must run exactly one miner and one uploader. Build agent is opt-in.

# M10.99Z273G_MAC_ARM_DEFAULT_BUILDER_AUTOUPDATE_SUPERVISOR

WORKER="${CODED_WORKER_NAME:-${WORKER}}"
DEVICE_ID="${CODED_DEVICE_ID:-macos-arm64:${WORKER}}"
WALLET="${CODED_WALLET:-EUELEOZEENRCEDYVEAZEBYVHQFABSUFFWTUWTFNSFALSTCNJLCDSEROGOSYI}"

BASE_DIR="${CODED_MAC_BASE_DIR:-/tmp/coded-miner-macos-arm64}"
BIN="$BASE_DIR/coded-miner"
UPLOADER="$BASE_DIR/coded_mac_arm_log_uploader.py"
MANIFEST="$BASE_DIR/release_manifest.json"

POOL="${CODED_POOL:-pool.codedonqubic.com:7777}"
POOL_API="${CODED_POOL_API:-http://pool.codedonqubic.com:4000/fleet/devices/heartbeat}"
LATEST_URL="${CODED_MAC_ARM_LATEST_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64.tar.gz}"

LOG="/tmp/coded-miner-${WORKER}.log"
UPLOG="/tmp/coded-mac-arm-uploader-${WORKER}.log"
SUPLOG="/tmp/coded-mac-arm-supervisor-${WORKER}.log"

# M10.99Z273M3_MAC1_LOG_ALIAS_FIX
# Z273M2 uses semantic log names; preserve compatibility with older LOG/UPLOG vars.
MINER_LOG="${MINER_LOG:-${LOG:-/tmp/coded-miner-${WORKER}.log}}"
UPLOADER_LOG="${UPLOADER_LOG:-${UPLOG:-/tmp/coded-mac-arm-uploader-${WORKER}.log}}"


CHECK_SEC="${CODED_SELF_UPDATE_CHECK_SEC:-60}"

# M10.99Z273M2_MAC1_PID_GUARD_SINGLE_UPLOADER
PID_DIR="${CODED_MAC_PID_DIR:-/tmp}"
SUPERVISOR_PID_FILE="$PID_DIR/coded-mac-arm-supervisor-${WORKER}.pid"
MINER_PID_FILE="$PID_DIR/coded-mac-arm-miner-${WORKER}.pid"
UPLOADER_PID_FILE="$PID_DIR/coded-mac-arm-uploader-${WORKER}.pid"
BUILD_FLAG="${CODED_MAC_BUILD_FLAG:-/tmp/coded-mac-arm-build-active-${WORKER}.flag}"
# M10.99Z273P_MAC1_BUILD_FLAG_SUPERVISOR_HANDOFF

THREADS="${CODED_THREADS:-1}"

export CODED_WORKER_NAME="$WORKER"
export CODED_DEVICE_ID="$DEVICE_ID"
export CODED_RUNTIME_MODE="${CODED_RUNTIME_MODE:-default_analytics}"
export CODED_DEVICE_ROLE="${CODED_DEVICE_ROLE:-default_analytics}"
export CODED_PRIORITY_ROUTER="${CODED_PRIORITY_ROUTER:-M1098E}"
export CODED_DEFAULT_ANALYTICS_PROFILE="${CODED_DEFAULT_ANALYTICS_PROFILE:-Z273B_ARM_M1098E_T321}"
export CODED_PROFILE_VERSION="${CODED_PROFILE_VERSION:-Z273B_ARM_DEFAULT_ANALYTICS_M1098E_T321_V1}"
export CODED_SELF_UPDATE_SUPERVISOR=1

export CODED_FORCE_FULLSCORE=1
export CODED_QATUM_REFERENCE_SCORE=1
export CODED_BACKEND=arm-portable
export CODED_ANALYTICS=YES
export CODED_FLEET_JOIN=YES
export CODED_FAST_SHADOW_GATE=1
export CODED_FAST_SHADOW_THRESHOLD=300
export CODED_FAST_SHADOW_AUDIT_RATE=1
export CODED_FAST_SHADOW_SUMMARY_SEC=10
export CODED_REAL_SCORE_AUDIT_DEBUG=1
export CODED_HI_TIMING=1
export CODED_SCORE_MODE=hyperidentity_only

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [Z273G] $*" | tee -a "$SUPLOG"
}

installed_version() {
  python3 - "$MANIFEST" <<'PY' 2>/dev/null || true
import json, sys
p=sys.argv[1]
try:
  print(json.load(open(p)).get("version",""))
except Exception:
  print("")
PY
}

remote_version_from_tar() {
  local tar="$1"
  tar -xOzf "$tar" release_manifest.json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("version",""))' 2>/dev/null || true
}

install_latest_if_new() {
  local tmp="/tmp/coded-mac-arm-latest-$$.tar.gz"
  local ex="/tmp/coded-mac-arm-latest-$$"
  rm -rf "$tmp" "$ex"

  if ! curl -fsSL "$LATEST_URL" -o "$tmp"; then
    log "latest download failed url=$LATEST_URL"
    return 0
  fi

  local remote installed
  remote="$(remote_version_from_tar "$tmp")"
  installed="$(installed_version)"

  if [ -z "$remote" ]; then
    log "latest manifest missing version"
    rm -f "$tmp"
    return 0
  fi

  if [ "$remote" = "$installed" ]; then
    log "latest already installed version=$installed"
    rm -f "$tmp"
    return 0
  fi

  log "new latest detected installed=${installed:-none} remote=$remote"

  pkill -f "$BIN.*--worker $WORKER" 2>/dev/null || true
  pkill -f "coded-miner.*$WORKER" 2>/dev/null || true
  sleep 2

  mkdir -p "$ex"
  tar -xzf "$tmp" -C "$ex"

  test -x "$ex/coded-miner" || { log "download invalid: missing coded-miner"; rm -rf "$tmp" "$ex"; return 0; }
  test -f "$ex/release_manifest.json" || { log "download invalid: missing manifest"; rm -rf "$tmp" "$ex"; return 0; }

  mkdir -p "$BASE_DIR"
  cp "$ex/coded-miner" "$BASE_DIR/coded-miner"
  chmod +x "$BASE_DIR/coded-miner"
  cp "$ex/release_manifest.json" "$BASE_DIR/release_manifest.json"

  if [ -f "$ex/coded_mac_arm_log_uploader.py" ]; then
    cp "$ex/coded_mac_arm_log_uploader.py" "$BASE_DIR/coded_mac_arm_log_uploader.py"
    chmod +x "$BASE_DIR/coded_mac_arm_log_uploader.py" || true
  fi

  log "installed latest version=$remote"
  rm -rf "$tmp" "$ex"
}

ensure_miner() {
  # M10.99Z273P_MAC1_BUILD_FLAG_SUPERVISOR_HANDOFF
  # During external ARM build the build-agent owns lifecycle. Do not restart miner.
  if [ -f "$BUILD_FLAG" ]; then
    log "build active; miner handoff enabled flag=$BUILD_FLAG"
    return 0
  fi

  if z273m2_pid_alive "$MINER_PID_FILE"; then
    return 0
  fi

  rm -f "$MINER_PID_FILE"
  z273m2_kill_orphan_miners

  local bin="$BASE_DIR/coded-miner"
  if [ ! -x "$bin" ]; then
    log "miner binary missing/not executable: $bin"
    return 0
  fi

  log "starting default miner worker=$WORKER"
  CODED_WORKER_NAME="$WORKER" \
  CODED_DEVICE_ID="$DEVICE_ID" \
  CODED_RUNTIME_MODE=default_analytics \
  CODED_DEVICE_ROLE=default_analytics \
  CODED_PRIORITY_ROUTER=M1098E \
  CODED_DEFAULT_ANALYTICS_PROFILE=Z273B_ARM_M1098E_T321 \
  CODED_PROFILE_VERSION=Z273B_ARM_DEFAULT_ANALYTICS_M1098E_T321_V1 \
  CODED_FORCE_FULLSCORE=1 \
  CODED_QATUM_REFERENCE_SCORE=1 \
  CODED_BACKEND=arm-portable \
  CODED_ANALYTICS=YES \
  CODED_FLEET_JOIN=YES \
  CODED_FAST_SHADOW_GATE=1 \
  CODED_FAST_SHADOW_THRESHOLD=300 \
  CODED_FAST_SHADOW_AUDIT_RATE=1 \
  CODED_FAST_SHADOW_SUMMARY_SEC=10 \
  CODED_REAL_SCORE_AUDIT_DEBUG=1 \
  CODED_HI_TIMING=1 \
  CODED_SCORE_MODE=hyperidentity_only \
  "$bin" \
    --pool "${CODED_POOL:-pool.codedonqubic.com:7777}" \
    --wallet "${CODED_WALLET:-EUELEOZEENRCEDYVEAZEBYVHQFABSUFFWTUWTFNSFALSTCNJLCDSEROGOSYI}" \
    --worker "$WORKER" \
    --threads "${CODED_THREADS:-1}" \
    >> "$MINER_LOG" 2>&1 &

  z273m2_write_pid "$MINER_PID_FILE" "$!"
}

ensure_uploader() {
  if z273m2_pid_alive "$UPLOADER_PID_FILE"; then
    return 0
  fi

  rm -f "$UPLOADER_PID_FILE"
  z273m2_kill_orphan_uploaders

  local uploader="$BASE_DIR/coded_mac_arm_log_uploader.py"
  if [ ! -f "$uploader" ]; then
    log "uploader missing: $uploader"
    return 0
  fi

  log "starting uploader worker=$WORKER"
  CODED_POOL_API="${CODED_POOL_API:-http://pool.codedonqubic.com:4000/fleet/devices/heartbeat}" \
  CODED_MAC_LOG="$MINER_LOG" \
  CODED_WORKER_NAME="$WORKER" \
  CODED_DEVICE_ID="$DEVICE_ID" \
  CODED_RUNTIME_MODE=default_analytics \
  CODED_DEVICE_ROLE=default_analytics \
  CODED_PRIORITY_ROUTER=M1098E \
  CODED_DEFAULT_ANALYTICS_PROFILE=Z273B_ARM_M1098E_T321 \
  CODED_PROFILE_VERSION=Z273B_ARM_DEFAULT_ANALYTICS_M1098E_T321_V1 \
  # M10.99Z273Z_SUPERVISOR_UPLOADER_ROLE_ENV
  CODED_SELF_UPDATE_SUPERVISOR="${CODED_SELF_UPDATE_ENABLED:-${AUTOUPDATE:-YES}}" \
  CODED_BUILDER="${CODED_ENABLE_BUILD_AGENT:-0}" \
  BUILDER="${CODED_ENABLE_BUILD_AGENT:-0}" \
  AUTOUPDATE="${CODED_SELF_UPDATE_ENABLED:-${AUTOUPDATE:-YES}}" \
  python3 "$uploader" >> "$UPLOADER_LOG" 2>&1 &

  z273m2_write_pid "$UPLOADER_PID_FILE" "$!"
}

ensure_build_agent() {
  # Optional: supports repo-local agent once present.
  local agent="${CODED_EXTERNAL_ARM_BUILD_AGENT:-/Users/chaosheld/Dev/coded-miner/scripts/external_arm_build_agent_z265b.sh}"
  if [ ! -x "$agent" ]; then
    return 0
  fi

  # M10.99Z273P3_SUPERVISOR_BUILD_AGENT_SINGLETON
  # Agent command line does not always include DEVICE_ID, so guard by script name.
  if pgrep -f "external_arm_build_agent_z265b.sh" >/dev/null 2>&1; then
    return 0
  fi

  log "starting external ARM build agent"
  CODED_DEVICE_ID="$DEVICE_ID" \
  CODED_WORKER_NAME="$WORKER" \
  CODED_POOL_API_ROOT="${CODED_POOL_API_ROOT:-http://pool.codedonqubic.com:4000}" \
  CODED_TARGET=macos-arm64 \
  CODED_BRANCH="${CODED_BRANCH:-z242-arm-hotpath-contract-clean}" \
  nohup "$agent" >> "/tmp/coded-mac-arm-build-agent-${WORKER}.log" 2>&1 &
}


z273m_pids() {
  local pattern="$1"
  ps -axo pid=,command= | grep -E "$pattern" | grep -v grep | awk '{print $1}' || true
}

z273m_kill_extra_pids() {
  local pattern="$1"
  local keep_pid="${2:-}"
  local pids pid first
  pids="$(z273m_pids "$pattern" || true)"
  first=""
  for pid in $pids; do
    if [ -n "$keep_pid" ] && [ "$pid" = "$keep_pid" ]; then
      continue
    fi
    if [ -z "$first" ]; then
      first="$pid"
      continue
    fi
    log "killing duplicate pid=$pid pattern=$pattern"
    kill -9 "$pid" >/dev/null 2>&1 || true
  done
}

z273m_singleton_guard() {
  local self="coded_mac_arm_supervisor_z273g.sh"
  local me="$$"
  local pids pid
  pids="$(ps -axo pid=,command= | grep "$self" | grep -v grep | awk '{print $1}' || true)"
  for pid in $pids; do
    if [ "$pid" != "$me" ] && [ "$pid" -lt "$me" ]; then
      log "older supervisor exists pid=$pid; exiting self=$me"
      exit 0
    fi
  done
}

z273m_cleanup_duplicates() {
  z273m_kill_extra_pids "/tmp/coded-run-${WORKER}\.sh"
  z273m_kill_extra_pids "coded_mac_arm_log_uploader.py"
  z273m_kill_extra_pids "/tmp/coded-miner-macos-arm64/coded-miner"
}


# M10.99Z273M2_MAC1_PID_GUARD_SINGLE_UPLOADER
z273m2_pid_alive() {
  local f="$1"
  [ -s "$f" ] || return 1
  local pid
  pid="$(cat "$f" 2>/dev/null || true)"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" >/dev/null 2>&1
}

z273m2_pid_cmd() {
  local f="$1"
  [ -s "$f" ] || return 0
  local pid
  pid="$(cat "$f" 2>/dev/null || true)"
  [ -n "$pid" ] || return 0
  ps -p "$pid" -o command= 2>/dev/null || true
}

z273m2_write_pid() {
  local f="$1"
  local pid="$2"
  echo "$pid" > "$f"
}

z273m2_kill_orphan_uploaders() {
  # M10.99Z273M4_NO_EXIT_ON_EMPTY_ORPHAN_SCAN
  # With set -euo pipefail, grep with zero matches must not terminate supervisor.
  local keep=""
  local rows=""
  if z273m2_pid_alive "$UPLOADER_PID_FILE"; then
    keep="$(cat "$UPLOADER_PID_FILE" 2>/dev/null || true)"
  fi

  rows="$(ps -axo pid=,command= | grep "coded_mac_arm_log_uploader.py" | grep -v grep || true)"
  [ -n "$rows" ] || return 0

  while read -r pid cmd; do
    [ -n "${pid:-}" ] || continue
    if [ -n "$keep" ] && [ "$pid" = "$keep" ]; then
      continue
    fi
    log "killing orphan uploader pid=$pid"
    kill -9 "$pid" >/dev/null 2>&1 || true
  done <<EOF
$rows
EOF
}

z273m2_kill_orphan_miners() {
  # M10.99Z273M4_NO_EXIT_ON_EMPTY_ORPHAN_SCAN
  # With set -euo pipefail, grep with zero matches must not terminate supervisor.
  local keep=""
  local rows=""
  if z273m2_pid_alive "$MINER_PID_FILE"; then
    keep="$(cat "$MINER_PID_FILE" 2>/dev/null || true)"
  fi

  rows="$(ps -axo pid=,command= | grep "/tmp/coded-miner-macos-arm64/coded-miner" | grep -v grep || true)"
  [ -n "$rows" ] || return 0

  while read -r pid cmd; do
    [ -n "${pid:-}" ] || continue
    if [ -n "$keep" ] && [ "$pid" = "$keep" ]; then
      continue
    fi
    log "killing orphan miner pid=$pid"
    kill -9 "$pid" >/dev/null 2>&1 || true
  done <<EOF
$rows
EOF
}

z273m2_status_line() {
  local installed="-"
  if [ -f "$BASE_DIR/release_manifest.json" ]; then
    installed="$(python3 - <<PY2 2>/dev/null || true
import json
p="$BASE_DIR/release_manifest.json"
try:
  print(json.load(open(p)).get("version","-"))
except Exception:
  print("-")
PY2
)"
  fi

  local miner_state="down"
  local uploader_state="down"

  if z273m2_pid_alive "$MINER_PID_FILE"; then miner_state="up:$(cat "$MINER_PID_FILE")"; fi
  if z273m2_pid_alive "$UPLOADER_PID_FILE"; then uploader_state="up:$(cat "$UPLOADER_PID_FILE")"; fi

  local build_state="idle"
  if [ -f "$BUILD_FLAG" ]; then build_state="active"; fi
  log "status installed=$installed miner=$miner_state uploader=$uploader_state build_agent=${CODED_ENABLE_BUILD_AGENT:-0} build=$build_state"
}

log "supervisor start worker=$WORKER device=$DEVICE_ID base=$BASE_DIR"
z273m_singleton_guard
z273m_cleanup_duplicates

while true; do
  z273m2_status_line
  z273m2_kill_orphan_miners
  z273m2_kill_orphan_uploaders
  install_latest_if_new
  ensure_miner
  ensure_uploader
  if [ "${CODED_ENABLE_BUILD_AGENT:-0}" = "1" ] && [ "${CODED_DISABLE_BUILD_AGENT:-0}" != "1" ]; then
    ensure_build_agent
  else
    log "build agent disabled; set CODED_ENABLE_BUILD_AGENT=1 to enable"
  fi
  sleep "$CHECK_SEC"
done
