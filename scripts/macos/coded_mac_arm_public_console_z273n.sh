#!/usr/bin/env bash
set -euo pipefail

# M10.99Z273N_MAC1_PUBLIC_TERMINAL_COCKPIT
# M10.99Z273X2_PUBLIC_CONSOLE_FLEET_COCKPIT_SAFE
# Public readable Mac1 terminal: default analytics, latest state, build progress.

WORKER="${CODED_WORKER_NAME:-${WORKER:-my-mac}}"
DEVICE_ID="${CODED_DEVICE_ID:-${DEVICE_ID:-macos-arm64:${WORKER}}}"

# M10.99Z273R_PUBLIC_CONSOLE_DYNAMIC_DEVICE
# M10.99Z273X3_AUTOUPDATE_LABEL_ALIAS
# Cockpit must not crash when either spelling is missing.
AUTOUPDATE_VALUE="${CODED_SELF_UPDATE_ENABLED:-${AUTOUPDATE:-YES}}"
AUTOUPDATE_LABEL="${AUTOUPDATE_VALUE}"
AUTUPDATE_LABEL="${AUTOUPDATE_LABEL}"
BUILDER_LABEL="${CODED_ENABLE_BUILD_AGENT:-${BUILDER:-0}}"

BASE_DIR="${CODED_MAC_BASE_DIR:-/tmp/coded-miner-macos-arm64}"
MINER_LOG="${CODED_MINER_LOG:-/tmp/coded-miner-${WORKER}.log}"
SUPLOG="${CODED_SUPERVISOR_LOG:-/tmp/coded-mac-arm-supervisor-${WORKER}.log}"
UPLOG="${CODED_UPLOADER_LOG:-/tmp/coded-mac-arm-uploader-${WORKER}.log}"
BUILD_LOG="${CODED_BUILD_LOG:-/tmp/coded-mac-arm-build-agent-${WORKER}.log}"
REMOTE_URL="${CODED_ARM_LATEST_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64.tar.gz}"
CHECK_SEC="${CODED_PUBLIC_CONSOLE_SEC:-5}"

GREEN=$'\033[32m'
RED=$'\033[31m'
YELLOW=$'\033[33m'
CYAN=$'\033[36m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

json_get() {
  local file="$1"
  local key="$2"
  python3 - "$file" "$key" <<'PY' 2>/dev/null || true
import json, sys
p, k = sys.argv[1], sys.argv[2]
try:
    with open(p, "r", encoding="utf-8") as f:
        d = json.load(f)
    print(d.get(k, ""))
except Exception:
    print("")
PY
}

installed_version() {
  json_get "$BASE_DIR/release_manifest.json" version
}

installed_commit() {
  json_get "$BASE_DIR/release_manifest.json" commit
}

remote_version() {
  local tmp="/tmp/coded-arm-public-console-latest"
  rm -rf "$tmp"
  mkdir -p "$tmp"
  curl -L --fail -sS \
    -H "Cache-Control: no-cache" \
    -H "Pragma: no-cache" \
    -o "$tmp/latest.tar.gz" \
    "$REMOTE_URL" >/dev/null 2>&1 || return 0

  tar -xOzf "$tmp/latest.tar.gz" release_manifest.json 2>/dev/null > "$tmp/manifest.json" \
    || tar -xOzf "$tmp/latest.tar.gz" ./release_manifest.json 2>/dev/null > "$tmp/manifest.json" \
    || return 0

  json_get "$tmp/manifest.json" version
}

build_percent() {
  if [ ! -f "$BUILD_LOG" ]; then
    echo ""
    return 0
  fi

  grep -Eo '\[[[:space:]]*[0-9]+%\]' "$BUILD_LOG" 2>/dev/null \
    | tail -n 1 \
    | tr -dc '0-9' || true
}

bar() {
  local pct="${1:-0}"
  local width=32
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local out=""
  for ((i=0;i<filled;i++)); do out="${out}█"; done
  for ((i=0;i<empty;i++)); do out="${out}░"; done
  echo "$out"
}

miner_metric() {
  local pattern="$1"
  grep -E "$pattern" "$MINER_LOG" 2>/dev/null | tail -n 1 || true
}

latest_audit_line() {
  grep -E "REAL_SCORE_AUDIT_DEBUG" "$MINER_LOG" 2>/dev/null | tail -n 1 || true
}

extract_real() {
  latest_audit_line | sed -n 's/.*real_score=\([0-9][0-9]*\).*/\1/p'
}

extract_shadow() {
  latest_audit_line | sed -n 's/.*shadow_score=\([0-9][0-9]*\).*/\1/p'
}

extract_count() {
  latest_audit_line | sed -n 's/.*count=\([0-9][0-9]*\).*/\1/p'
}

proc_state() {
  local miner_count uploader_count supervisor_count build_count
  miner_count="$(pgrep -f "/tmp/coded-miner-macos-arm64/coded-miner.*--worker ${WORKER}" | wc -l | tr -d ' ')"
  uploader_count="$(pgrep -f "coded_mac_arm_log_uploader.py" | wc -l | tr -d ' ')"
  supervisor_count="$(pgrep -f "coded_mac_arm_supervisor_z273g.sh" | wc -l | tr -d ' ')"
  build_count="$(pgrep -f "external.*build|cmake|coded-bench|coded-runtime-test" | wc -l | tr -d ' ')"

  echo "$miner_count" "$uploader_count" "$supervisor_count" "$build_count"
}

clear_screen() {
  printf '\033[2J\033[H'
}

while true; do
  iv="$(installed_version)"
  ic="$(installed_commit)"
  rv="$(remote_version)"
  [ -n "$iv" ] || iv="unknown"
  [ -n "$rv" ] || rv="unknown"

  read -r miner_count uploader_count supervisor_count build_count <<<"$(proc_state)"

  pct="$(build_percent)"
  if [ -n "$pct" ] && [ "${pct:-0}" -gt 0 ] && [ "${pct:-0}" -lt 100 ]; then
    mode="${YELLOW}BUILDING${RESET}"
    mode_line="${YELLOW}$(bar "$pct") ${pct}%${RESET}"
  else
    mode="${GREEN}MINING DEFAULT ANALYTICS${RESET}"
    mode_line="${GREEN}$(bar 100) 100% runtime steady${RESET}"
  fi

  if [ "$iv" = "$rv" ] && [ "$iv" != "unknown" ]; then
    latest_state="${GREEN}LATEST${RESET}"
  elif [ "$rv" != "unknown" ]; then
    latest_state="${YELLOW}UPDATE AVAILABLE${RESET}"
  else
    latest_state="${DIM}LATEST UNKNOWN${RESET}"
  fi

  real="$(extract_real)"
  shadow="$(extract_shadow)"
  count="$(extract_count)"
  [ -n "$real" ] || real="-"
  [ -n "$shadow" ] || shadow="-"
  [ -n "$count" ] || count="-"

  clear_screen
  echo "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${RESET}"
  echo "${BOLD}${CYAN}║                     CODED MAC ARM FLEET COCKPIT                            ║${RESET}"
  echo "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${RESET}"
  echo
  role_label="PUBLIC DEFAULT WORKER"
  if [ "${CODED_ENABLE_BUILD_AGENT:-0}" = "1" ] || [ "${BUILDER:-0}" = "1" ]; then
    role_label="BUILDER + DEFAULT WORKER"
  fi

  echo "${BOLD}IDENTITY${RESET}"
  echo "  device       $DEVICE_ID"
  echo "  worker       $WORKER"
  echo "  role         $role_label"
  echo
  echo "${BOLD}LIFECYCLE${RESET}"
  echo "  mode         $mode"
  echo "  autoupdate   $AUTOUPDATE_LABEL"
  echo "  builder      $BUILDER_LABEL"
  echo "  version      $latest_state"
  echo "  installed    $iv"
  echo "  remote       $rv"
  echo "  commit       ${ic:0:12}"
  echo
  echo "  progress     $mode_line"
  echo
  echo "${BOLD}PROCESSES${RESET}"
  echo "  supervisor   $supervisor_count"
  echo "  miner        $miner_count"
  echo "  uploader     $uploader_count"
  echo "  build jobs   $build_count"
  echo
  echo "${BOLD}SCORING / REALSCORE${RESET}"
  echo "  audits       $count"
  echo "  real max     $real"
  echo "  shadow max   $shadow"
  echo "  threshold    321"
  echo "  router       M1098E"
  echo "  target       real>=321 · false_negative=0"
  echo
  echo "${DIM}--- supervisor tail ---${RESET}"
  tail -n 8 "$SUPLOG" 2>/dev/null || true
  echo
  echo "${DIM}--- build tail ---${RESET}"
  tail -n 8 "$BUILD_LOG" 2>/dev/null || true
  echo
  echo "${DIM}refresh=${CHECK_SEC}s · Ctrl+C closes only this cockpit · miner/supervisor keep running${RESET}"

  sleep "$CHECK_SEC"
done
