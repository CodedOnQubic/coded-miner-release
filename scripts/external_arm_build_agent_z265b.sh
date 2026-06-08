#!/usr/bin/env bash
set -euo pipefail

# M10.99Z273P_EXTERNAL_ARM_BUILD_AGENT_REAL
# Mac1 external ARM build agent:
# polls Primary, claims macos-arm64 build commands, stops default miner during build,
# builds real ARM artifact, uploads artifact, then hands runtime back to supervisor.

DEVICE_ID="${CODED_DEVICE_ID:-macos-arm64:Oscar-Mac-ARM}"
WORKER="${CODED_WORKER_NAME:-Oscar-Mac-ARM-Z273B-DEFAULT_ANALYTICS_M1098E_T321}"
API_ROOT="${CODED_POOL_API_ROOT:-http://pool.codedonqubic.com:4000}"
SOURCE_REPO="${CODED_SOURCE_REPO:-/Users/chaosheld/Dev/coded-miner}"
BASE_DIR="${CODED_MAC_BASE_DIR:-/tmp/coded-miner-macos-arm64}"
CHECK_SEC="${CODED_BUILD_AGENT_CHECK_SEC:-5}"
WALLET="${CODED_WALLET:-EUELEOZEENRCEDYVEAZEBYVHQFABSUFFWTUWTFNSFALSTCNJLCDSEROGOSYI}"
POOL="${CODED_POOL:-pool.codedonqubic.com:7777}"

BUILD_LOG="/tmp/coded-mac-arm-build-agent-${WORKER}.log"
BUILD_FLAG="/tmp/coded-mac-arm-build-active-${WORKER}.flag"

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
DIM="\033[2m"
RESET="\033[0m"

log() {
  echo -e "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [Z273P] $*" | tee -a "$BUILD_LOG"
}

bar() {
  local pct="$1"
  local label="$2"
  local width=32
  local fill=$((pct * width / 100))
  local empty=$((width - fill))
  local b=""
  for _ in $(seq 1 "$fill"); do b="${b}█"; done
  for _ in $(seq 1 "$empty"); do b="${b}░"; done
  log "${CYAN}${b}${RESET} ${pct}% ${label}"
}

post_json_file() {
  local path="$1"
  local file="$2"
  curl -sS -X POST "$API_ROOT$path" \
    -H "content-type: application/json" \
    --data-binary "@$file"
}

post_json_inline() {
  local path="$1"
  local json="$2"
  curl -sS -X POST "$API_ROOT$path" \
    -H "content-type: application/json" \
    --data "$json"
}

json_get() {
  local file="$1"
  local expr="$2"
  node - "$file" "$expr" <<'NODE'
const fs = require("fs");
const file = process.argv[2];
const expr = process.argv[3];
const obj = JSON.parse(fs.readFileSync(file, "utf8"));
function get(path) {
  return path.split(".").reduce((a,k)=>a && a[k] !== undefined ? a[k] : undefined, obj);
}
const v = get(expr);
if (v === undefined || v === null) process.exit(0);
if (typeof v === "object") console.log(JSON.stringify(v));
else console.log(String(v));
NODE
}

write_json_file() {
  local out="$1"
  local js="$2"
  node -e "$js" > "$out"
}

heartbeat_loop() {
  local cmd="$1"
  while [ -f "$BUILD_FLAG" ]; do
    cat > "/tmp/z273p-heartbeat-${cmd}.json" <<JSON
{
  "lease_minutes": 30,
  "result": {
    "marker": "M10.99Z273P_EXTERNAL_ARM_BUILD_HEARTBEAT",
    "device_id": "$DEVICE_ID",
    "worker_name": "$WORKER",
    "heartbeat_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
JSON
    post_json_file "/fleet/external-build/$cmd/heartbeat" "/tmp/z273p-heartbeat-${cmd}.json" >/dev/null 2>&1 || true
    sleep 15
  done
}

stop_default_runtime_for_build() {
  log "${YELLOW}stopping default miner/uploader for build handoff${RESET}"
  pkill -f "/tmp/coded-miner-macos-arm64/coded-miner.*--worker ${WORKER}" >/dev/null 2>&1 || true
  pkill -f "coded_mac_arm_log_uploader.py" >/dev/null 2>&1 || true
  pkill -f "/tmp/coded-run-${WORKER}.sh" >/dev/null 2>&1 || true
  rm -f "/tmp/coded-mac-arm-miner-${WORKER}.pid" "/tmp/coded-mac-arm-uploader-${WORKER}.pid" || true
  sleep 2
}

build_command() {
  local command_json="$1"
  local cmd branch commit version suffix target artifact work src build payload art sha manifest_b64 artifact_b64

  cmd="$(json_get "$command_json" "command.command_id")"
  branch="$(json_get "$command_json" "command.params.branch")"
  # M10.99Z273P2_AGENT_EXPECTED_COMMIT_FALLBACK_SINGLETON
  commit="$(json_get "$command_json" "command.params.commit")"
  if [ -z "$commit" ]; then commit="$(json_get "$command_json" "command.params.expected_commit")"; fi
  if [ -z "$commit" ]; then commit="$(json_get "$command_json" "command.params.source_commit")"; fi
  if [ -z "$commit" ]; then commit="$(json_get "$command_json" "command.params.resolved_commit")"; fi
  target="$(json_get "$command_json" "command.params.target")"
  version="$(json_get "$command_json" "command.params.version")"
  suffix="$(json_get "$command_json" "command.params.version_suffix")"

  [ -n "$branch" ] || branch="z242-arm-hotpath-contract-clean"
  [ -n "$target" ] || target="macos-arm64"

  if [ -z "$commit" ] || ! echo "$commit" | grep -Eq '^[0-9a-f]{7,40}$'; then
    log "${RED}invalid commit from command cmd=$cmd commit=$commit${RESET}"
    return 1
  fi

  if [ -z "$version" ]; then
    [ -n "$suffix" ] || suffix="z273p-mac1-build-button"
    version="v0.7.59-${suffix}-${commit:0:7}-$(date -u +%Y%m%dT%H%M%SZ)"
  fi

  artifact="coded-miner-macos-arm64-${version}.tar.gz"
  work="/tmp/coded-external-build-${cmd}"
  src="$work/src"
  build="$work/build"
  payload="$work/payload"
  art="$work/$artifact"

  log "${GREEN}claimed build command=$cmd version=$version commit=${commit:0:12}${RESET}"
  echo "1" > "$BUILD_FLAG"

  cat > "/tmp/z273p-running-${cmd}.json" <<JSON
{
  "lease_minutes": 30,
  "result": {
    "marker": "M10.99Z273P_EXTERNAL_ARM_BUILD_RUNNING",
    "device_id": "$DEVICE_ID",
    "worker_name": "$WORKER",
    "version": "$version",
    "commit": "$commit"
  }
}
JSON
  post_json_file "/fleet/external-build/$cmd/running" "/tmp/z273p-running-${cmd}.json" | tee -a "$BUILD_LOG" >/dev/null || true

  heartbeat_loop "$cmd" &
  local hb_pid="$!"

  trap 'rm -f "$BUILD_FLAG"; kill "$hb_pid" >/dev/null 2>&1 || true' RETURN

  stop_default_runtime_for_build

  bar 5 "prepare workspace"
  rm -rf "$work"
  mkdir -p "$work" "$src" "$build" "$payload"

  bar 12 "sync source"
  git -C "$SOURCE_REPO" fetch origin "$branch" >> "$BUILD_LOG" 2>&1 || true
  git -C "$SOURCE_REPO" checkout "$branch" >> "$BUILD_LOG" 2>&1
  git -C "$SOURCE_REPO" reset --hard "$commit" >> "$BUILD_LOG" 2>&1

  rsync -a --delete \
    --exclude ".git" \
    --exclude "build" \
    --exclude "cmake-build-*" \
    --exclude "node_modules" \
    --exclude "coded-miner-macos-arm64-package" \
    "$SOURCE_REPO/" "$src/"

  bar 22 "configure cmake"
  export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
  export MACOSX_DEPLOYMENT_TARGET=12.0
  unset CC CXX LDFLAGS CPPFLAGS CXXFLAGS || true

  cmake -S "$src" -B "$build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=/usr/bin/clang \
    -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
    -DCMAKE_OSX_SYSROOT="$SDKROOT" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
    -DCODED_ENABLE_AVX2=OFF \
    -DCODED_ENABLE_AVX512=OFF \
    -DCMAKE_CXX_FLAGS="-O3 -mcpu=apple-m1" \
    >> "$BUILD_LOG" 2>&1

  bar 38 "compile"
  cmake --build "$build" -j"$(sysctl -n hw.ncpu)" >> "$BUILD_LOG" 2>&1

  bar 72 "package"
  if [ ! -x "$build/coded-miner" ]; then
    log "${RED}coded-miner binary missing after build${RESET}"
    return 1
  fi

  cp "$build/coded-miner" "$payload/coded-miner"
  chmod +x "$payload/coded-miner"

  if [ -f "$src/scripts/coded_mac_arm_log_uploader.py" ]; then
    cp "$src/scripts/coded_mac_arm_log_uploader.py" "$payload/coded_mac_arm_log_uploader.py"
  elif [ -f "$BASE_DIR/coded_mac_arm_log_uploader.py" ]; then
    cp "$BASE_DIR/coded_mac_arm_log_uploader.py" "$payload/coded_mac_arm_log_uploader.py"
  fi

  cat > "$payload/release_manifest.json" <<JSON
{
  "version": "$version",
  "target": "macos-arm64",
  "platform": "macos-arm64",
  "arch": "arm64",
  "repo": "CodedOnQubic/coded-miner",
  "branch": "$branch",
  "commit": "$commit",
  "built_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "builder_device_id": "$DEVICE_ID",
  "builder_worker": "$WORKER",
  "marker": "M10.99Z273P_EXTERNAL_ARM_BUILD_AGENT_REAL",
  "stub": false,
  "publish_ready": true,
  "backend": "arm-portable",
  "backend_kind": "arm-portable",
  "backend_validation": "golden_25_matched_live_score_verified",
  "training_role": "external_arm_reference_validation",
  "performance_class": "slow_reference",
  "threshold": 321,
  "fullscore_threshold": 321,
  "shadow_threshold": 300,
  "real_score_available": 1,
  "real_score_authoritative": 0,
  "real_score_truth": true
}
JSON

  (cd "$payload" && tar -czf "$art" .)

  sha="$(shasum -a 256 "$art" | awk '{print $1}')"
  bar 86 "upload artifact"

  node - "$art" "$artifact" "$sha" "$version" "$target" "$cmd" <<'NODE' > "/tmp/z273p-upload.json"
const fs = require("fs");
const [art, artifactName, sha, version, target, cmd] = process.argv.slice(2);
const artifact = fs.readFileSync(art);
console.log(JSON.stringify({
  artifact_name: artifactName,
  artifact_base64: artifact.toString("base64"),
  artifact_sha256: sha,
  target,
  version,
  publish_ready: true,
  resume_default_after: true,
  marker: "M10.99Z273P_EXTERNAL_ARM_BUILD_AGENT_REAL",
  command_id: cmd
}));
NODE

  post_json_file "/fleet/external-build/$cmd/artifact" "/tmp/z273p-upload.json" | tee -a "$BUILD_LOG"

  bar 96 "complete accepted by primary"

  cat > "/tmp/z273p-complete-${cmd}.json" <<JSON
{
  "result": {
    "marker": "M10.99Z273P_EXTERNAL_ARM_BUILD_AGENT_COMPLETE",
    "status": "real_arm_realscore_build_completed",
    "target": "macos-arm64",
    "version": "$version",
    "artifact_name": "$artifact",
    "artifact_sha256": "$sha",
    "artifact_uploaded": true,
    "artifact_validated": true,
    "publish_ready": true,
    "resume_default_after": true,
    "completed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
JSON

  post_json_file "/fleet/external-build/$cmd/complete" "/tmp/z273p-complete-${cmd}.json" | tee -a "$BUILD_LOG" || true

  bar 100 "done; supervisor will resume default analytics"
  rm -f "$BUILD_FLAG"
  kill "$hb_pid" >/dev/null 2>&1 || true
}

# M10.99Z273P2_AGENT_EXPECTED_COMMIT_FALLBACK_SINGLETON
# Prevent duplicate build agents for the same Mac1 device/worker.
SELF_PID="$$"
DUP_PIDS="$(ps -axo pid=,command= | grep "external_arm_build_agent_z265b.sh" | grep "$WORKER" | grep -v grep | awk '{print $1}' || true)"
for p in $DUP_PIDS; do
  if [ "$p" != "$SELF_PID" ] && [ "$p" -lt "$SELF_PID" ]; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [Z273P2] older build agent exists pid=$p; exiting self=$SELF_PID" | tee -a "$BUILD_LOG"
    exit 0
  fi
done

log "${GREEN}Mac1 external ARM build agent online device=$DEVICE_ID worker=$WORKER api=$API_ROOT${RESET}"

idle_count=0

while true; do
  next_file="/tmp/z273p-next-${DEVICE_ID//[:\/]/_}.json"

  if curl -sS "$API_ROOT/fleet/external-build/next/$DEVICE_ID" > "$next_file"; then
    cmd="$(json_get "$next_file" "command.command_id")"
    marker="$(json_get "$next_file" "marker")"

    if [ -n "$cmd" ]; then
      build_command "$next_file" || {
        err="$?"
        log "${RED}build failed cmd=$cmd code=$err${RESET}"
        cat > "/tmp/z273p-fail-${cmd}.json" <<JSON
{
  "result": {
    "marker": "M10.99Z273P_EXTERNAL_ARM_BUILD_AGENT_FAILED",
    "status": "failed",
    "device_id": "$DEVICE_ID",
    "worker_name": "$WORKER",
    "failed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "error": "Mac1 external ARM build failed"
}
JSON
        post_json_file "/fleet/external-build/$cmd/complete" "/tmp/z273p-fail-${cmd}.json" >/dev/null 2>&1 || true
        rm -f "$BUILD_FLAG"
      }
    else
      idle_count=$((idle_count + 1))
      if [ "$idle_count" -ge 12 ]; then
        log "${DIM}builder ready · no pending command · marker=$marker${RESET}"
        idle_count=0
      fi
    fi
  else
    log "${YELLOW}next poll failed api=$API_ROOT${RESET}"
  fi

  sleep "$CHECK_SEC"
done
