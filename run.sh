#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-latest}"
POOL="${POOL:-pool.codedonqubic.com:7777}"
WALLET="${WALLET:-}"
WORKER="${WORKER:-coded-mac}"
THREADS="${THREADS:-${CODED_THREADS:-${COMMAND_THREADS:-0}}}"

CHANNEL="${CHANNEL:-main}"
BASE_URL="${BASE_URL:-https://github.com/CodedOnQubic/coded-miner-release/raw/${CHANNEL}}"

# M10.99Z200_MAC_ARM_FULLSCORE_PUBLIC_RUN
CODED_ANALYTICS="${CODED_ANALYTICS:-}"
if [ -z "$CODED_ANALYTICS" ]; then
  OLD_ANALYTICS="${oded_analytics:-${ODED_ANALYTICS:-}}"
  case "$(echo "$OLD_ANALYTICS" | tr '[:lower:]' '[:upper:]')" in
    YES|TRUE|1|ON) CODED_ANALYTICS="YES" ;;
  esac
fi

export CODED_ANALYTICS="${CODED_ANALYTICS:-YES}"
export CODED_FLEET_JOIN="${CODED_FLEET_JOIN:-YES}"
export CODED_FORCE_FULLSCORE="${CODED_FORCE_FULLSCORE:-1}"
export CODED_FULLSCORE_ALL_BACKENDS="${CODED_FULLSCORE_ALL_BACKENDS:-1}"
export CODED_PREFILTER_DIFFICULTY="${CODED_PREFILTER_DIFFICULTY:-0}"

# M10.99Z212A_ENABLE_FULLPATH_QUALITY_TELEMETRY
# Enable comparable quality telemetry on public Mac ARM fleet devices.
# Fullscore-all-backends remains authoritative, so routers may observe but not suppress.
export CODED_FAST_SHADOW_GATE="${CODED_FAST_SHADOW_GATE:-1}"
export CODED_FAST_SHADOW_SUMMARY_SEC="${CODED_FAST_SHADOW_SUMMARY_SEC:-10}"
export CODED_FAST_SHADOW_BATCH_LOG="${CODED_FAST_SHADOW_BATCH_LOG:-1}"
export CODED_PRIORITY_BUDGET_ROUTER="${CODED_PRIORITY_BUDGET_ROUTER:-1}"

# M10.99Z213A_DISABLE_PUBLIC_HI_TIMING_SPAM
# Public fleet logs must stay parseable and small. HI_TIMING is profiling-only.
export CODED_HI_TIMING="${CODED_HI_TIMING:-0}"
export CODED_DISABLE_HI_TIMING="${CODED_DISABLE_HI_TIMING:-1}"
export CODED_HI_TIMING_SUMMARY_SEC="${CODED_HI_TIMING_SUMMARY_SEC:-0}"
export CODED_RELEASE_CHANNEL="${CODED_RELEASE_CHANNEL:-${CHANNEL}}"
export CODED_VERSION="${CODED_VERSION:-${VERSION}}"

# M10.99Z202_MAC_ARM_FLEET_DEFAULT_ANALYTICS
# Public Mac/Docker devices should join as fleet-capable default analytics workers.
export CODED_FLEET_JOIN="${CODED_FLEET_JOIN:-YES}"
export CODED_RUNTIME_MODE="${CODED_RUNTIME_MODE:-default_analytics}"
export CODED_COMMAND_MODE="${CODED_COMMAND_MODE:-poll}"
export CODED_DEVICE_ROLE="${CODED_DEVICE_ROLE:-default_analytics}"
export CODED_EXPERIMENT_READY="${CODED_EXPERIMENT_READY:-YES}"
export CODED_RELEASE_BUILD_READY="YES"
export CODED_CAPABILITIES_UPLOAD="${CODED_CAPABILITIES_UPLOAD:-YES}"
export CODED_THREADS="${CODED_THREADS:-$THREADS}"
export COMMAND_THREADS="${COMMAND_THREADS:-$THREADS}"

if [ -z "$WALLET" ]; then
  echo "[ERROR] WALLET missing"
  echo "Usage:"
  echo 'WALLET=YOUR_WALLET WORKER=my-mac bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"'
  exit 1
fi

OS="$(uname -s)"
ARCH="$(uname -m)"


# M10.99Z203A_EXTERNAL_FLEET_HEARTBEAT
API_URL="${API_URL:-https://api.codedonqubic.com}"

# M10.99Z204B_CANONICAL_EXTERNAL_ANALYTICS_HEARTBEAT
CODED_STARTED_AT="${CODED_STARTED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
CODED_RUNTIME_LOG="${CODED_RUNTIME_LOG:-/tmp/coded-miner-${WORKER}.log}"
: > "$CODED_RUNTIME_LOG"
CODED_HI_METRICS_STATE="${CODED_HI_METRICS_STATE:-/tmp/coded-miner-${WORKER}.hi.state}"
CODED_HI_METRICS_CACHE="${CODED_HI_METRICS_CACHE:-/tmp/coded-miner-${WORKER}.hi.cache}"

CODED_VERBOSE_HI="${CODED_VERBOSE_HI:-0}"

# M10.99Z217A_MAC_SELF_UPDATE_DEFAULTS
export CODED_SELF_UPDATE="${CODED_SELF_UPDATE:-1}"
export CODED_SELF_UPDATE_SEC="${CODED_SELF_UPDATE_SEC:-60}"
export CODED_RELEASE_BASE_URL="${CODED_RELEASE_BASE_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main}"
export CODED_LATEST_MACOS_ARM64_URL="${CODED_LATEST_MACOS_ARM64_URL:-$CODED_RELEASE_BASE_URL/latest-macos-arm64.txt}"
export CODED_CURRENT_RELEASE_FILE="${CODED_CURRENT_RELEASE_FILE:-}"

# M10.99Z217B_OUTER_SUPERVISOR_LOOP
# Parent process for public Mac fleet join.
# Keeps foreign Macs alive and auto-updated without manual restart.
if [ "${CODED_SUPERVISOR_CHILD:-0}" != "1" ] && [ "${CODED_SELF_UPDATE_SUPERVISOR:-1}" = "1" ]; then
  export CODED_SELF_UPDATE_SUPERVISOR=1

  cleanup_supervisor() {
    if [ -n "${CODED_CHILD_PID:-}" ]; then
      kill -TERM "$CODED_CHILD_PID" 2>/dev/null || true
      sleep 1
      kill -KILL "$CODED_CHILD_PID" 2>/dev/null || true
    fi
    exit 0
  }

  trap cleanup_supervisor INT TERM

  echo "[CODED] Fleet supervisor active: worker=${WORKER:-unknown} update_sec=${CODED_SELF_UPDATE_SEC:-60}"

  while true; do
    TMP_RUN="/tmp/coded-run-${WORKER:-worker}.sh"

    curl -fsSL "https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh?supervisor=$(date +%s)" \
      -o "$TMP_RUN" || {
        echo "[CODED] Supervisor: failed to fetch latest run.sh, retrying..."
        sleep "${CODED_SELF_UPDATE_SEC:-60}"
        continue
      }

    chmod +x "$TMP_RUN"

    CODED_SUPERVISOR_CHILD=1 \
    CODED_SELF_UPDATE_SUPERVISOR=0 \
    bash "$TMP_RUN" &
    CODED_CHILD_PID="$!"

    wait "$CODED_CHILD_PID" || true
    CODED_CHILD_PID=""

    echo "[CODED] Supervisor: miner child exited, refreshing latest release..."
    sleep 3
  done
fi



# M10.99Z211_CLEAN_USER_CONSOLE_WHITELIST
# Runtime log keeps full miner output for analytics.
# Terminal output is intentionally clean for public Mac users.
coded_console_filter() {
  if [ "${CODED_VERBOSE_HI:-0}" = "1" ]; then
    cat
    return 0
  fi

  awk '
    /^\[CODED\]/ { print; fflush(); next }
    /^CODED Miner starting/ { print; fflush(); next }
    /^\[CODED_RUNTIME_CONTRACT\]/ { print; fflush(); next }
    /^=+$/ { print; fflush(); next }
    /^[[:space:]]*$/ { next }

    /^\[RUNTIME\]/ { print; fflush(); next }
    /^\[WARN\]/ { print; fflush(); next }
    /^\[ERROR\]/ { print; fflush(); next }
    /^\[POOL_Z207C_TOLERANT_PACKET_HANDLED\]/ { next }
    /^\[POOL_/ { next }

    /^\[ \$0\.01 CODED \]/ { print; fflush(); next }

    # Drop all noisy profiling fragments, including broken/partial HI_TIMING lines.
    /HI_TIMING/ { next }
    /global_count=/ { next }
    /local_count=/ { next }
    /local_avg_ms=/ { next }
    /algo0_count=/ { next }
    /algo0_avg_ms=/ { next }
    /algo0_max_ms=/ { next }
    /algo1_count=/ { next }
    /score=0 algo=/ { next }
    /^0(\.[0-9]+)?[[:space:]]+local_avg_ms=/ { next }
    /^local_count=/ { next }
    /^score=0 algo=/ { next }
    /^algo=0$/ { next }
    /^0$/ { next }

    # Hide everything else by default.
    { next }
  '
}


# M10.99Z208_HI_TIMING_METRICS_FALLBACK
compute_hi_timing_its() {
  if [ ! -f "$CODED_RUNTIME_LOG" ]; then
    echo 0
    return 0
  fi

  local total
  total="$(tail -n 300 "$CODED_RUNTIME_LOG" | grep -Eo 'global_count=[0-9]+' | tail -1 | cut -d= -f2 || true)"
  if [ -z "$total" ]; then
    total="$(tail -n 300 "$CODED_RUNTIME_LOG" | grep -Eo 'total=[0-9]+' | tail -1 | cut -d= -f2 || true)"
  fi

  if [ -z "$total" ]; then
    echo 0
    return 0
  fi

  local now prev_t prev_total rate
  now="$(date +%s)"

  if [ -f "$CODED_HI_METRICS_STATE" ]; then
    read -r prev_t prev_total < "$CODED_HI_METRICS_STATE" || true
  fi

  echo "$now $total" > "$CODED_HI_METRICS_STATE"

  if [ -z "${prev_t:-}" ] || [ -z "${prev_total:-}" ]; then
    echo 0
    return 0
  fi

  local dt=$((now - prev_t))
  local dc=$((total - prev_total))

  if [ "$dt" -le 0 ] || [ "$dc" -le 0 ]; then
    if [ -f "$CODED_HI_METRICS_CACHE" ]; then
      cat "$CODED_HI_METRICS_CACHE"
    else
      echo 0
    fi
    return 0
  fi

  rate=$((dc / dt))
  echo "$rate" > "$CODED_HI_METRICS_CACHE"
  echo "$rate"
}


coded_json_bool() {
  case "$1" in
    YES|yes|true|TRUE|1|ON|on) echo true ;;
    *) echo false ;;
  esac
}

parse_runtime_state() {
  if [ ! -f "$CODED_RUNTIME_LOG" ]; then
    echo "starting"
    return 0
  fi

  if tail -n 120 "$CODED_RUNTIME_LOG" | grep -q "mining active"; then
    echo "mining_active"
    return 0
  fi

  if tail -n 120 "$CODED_RUNTIME_LOG" | grep -q "WAITING FOR NEW SEED\|waiting for new seed\|waiting for first job"; then
    echo "waiting_for_seed"
    return 0
  fi

  if tail -n 120 "$CODED_RUNTIME_LOG" | grep -q "Pool client not connected\|Reconnecting"; then
    echo "reconnecting"
    return 0
  fi

  if [ "$(parse_status_last_its)" != "0" ] || [ "$(parse_status_avg_its)" != "0" ]; then
    echo "mining_active"
    return 0
  fi

  echo "running"
}


# M10.99Z212D_STABLE_STATUS_ITS_ONLY
# Public fleet speed must come from complete miner status lines, not HI_TIMING global_count.
# HI_TIMING can count internal scoring calls and can be interleaved, causing impossible 50M+ spikes.
parse_status_last_its() {
  if [ ! -f "$CODED_RUNTIME_LOG" ]; then
    echo 0
    return 0
  fi

  local value
  value="$(tail -n 500 "$CODED_RUNTIME_LOG" \
    | grep 'SOLS:' \
    | grep -Eo '\[[A-Za-z0-9_-]+\] [0-9.,]+ it/s' \
    | tail -1 \
    | awk '{print $(NF-1)}' \
    | tr -d ',.' || true)"

  if [ -z "$value" ]; then
    echo 0
    return 0
  fi

  echo "$value"
}

parse_status_avg_its() {
  if [ ! -f "$CODED_RUNTIME_LOG" ]; then
    echo 0
    return 0
  fi

  local value
  value="$(tail -n 500 "$CODED_RUNTIME_LOG" \
    | grep 'SOLS:' \
    | grep -Eo '[0-9.,]+ avg it/s' \
    | tail -1 \
    | awk '{print $1}' \
    | tr -d ',.' || true)"

  if [ -z "$value" ]; then
    echo 0
    return 0
  fi

  echo "$value"
}

sanitize_public_its() {
  local v="$1"
  local max="${CODED_MAX_PUBLIC_ITS:-12000000}"

  if [ -z "$v" ] || [ "$v" = "null" ]; then
    echo 0
    return 0
  fi

  awk -v v="$v" -v max="$max" 'BEGIN {
    if (v < 0 || v > max) print 0;
    else printf "%.0f", v;
  }'
}

parse_last_its() {
  local v
  v="$(parse_status_last_its)"
  sanitize_public_its "$v"
}


# M10.99Z212E_NONZERO_FAST_SHADOW_SUMMARY_QUALITY
parse_quality_metric() {
  local key="$1"
  if [ ! -f "$CODED_RUNTIME_LOG" ]; then
    echo null
    return 0
  fi

  # Use only complete FAST_SHADOW_SUMMARY lines with total_seen > 0.
  # Early zero summaries are not useful for frontend/pipeline quality state.
  local line value
  line="$(tail -n 5000 "$CODED_RUNTIME_LOG" \
    | grep 'FAST_SHADOW_SUMMARY' \
    | awk '
      {
        seen = 0
        if (match($0, /total_seen=[0-9]+/)) {
          s = substr($0, RSTART, RLENGTH)
          sub("total_seen=", "", s)
          seen = s + 0
        }
        if (seen > 0) print $0
      }
    ' \
    | tail -1 || true)"

  if [ -z "$line" ]; then
    echo null
    return 0
  fi

  value="$(printf "%s
" "$line" \
    | grep -Eo "${key}=[0-9.]+" \
    | tail -1 \
    | cut -d= -f2 || true)"

  if [ -z "$value" ]; then
    echo null
    return 0
  fi

  case "$key" in
    pass_rate)
      awk -v v="$value" 'BEGIN { if (v >= 0 && v <= 100) print v; else print "null"; }'
      ;;
    *)
      echo "$value"
      ;;
  esac
}


parse_total_seen() {
  parse_quality_metric total_seen
}

parse_total_pass() {
  parse_quality_metric total_pass
}

parse_total_skip() {
  parse_quality_metric total_skip
}

parse_false_negative() {
  local v
  v="$(parse_quality_metric false_negative)"
  [ "$v" = "null" ] && echo 0 || echo "$v"
}

parse_max_real_score_passed() {
  local v
  v="$(parse_quality_metric max_real_score_passed)"
  [ "$v" = "null" ] && echo 0 || echo "$v"
}

# M10.99Z218C_PARSE_REAL_AUDIT_FIELDS
parse_max_real_score_seen() {
  local v
  v="$(parse_quality_metric max_real_score_seen)"
  [ "$v" = "null" ] && echo 0 || echo "$v"
}

# M10.99Z219D_PARSE_REAL_SCORE_AVAILABLE
parse_real_score_available() {
  local v
  v="$(parse_quality_metric real_score_available)"
  [ "$v" = "null" ] && echo 0 || echo "$v"
}

parse_total_audited() {
  local v
  v="$(parse_quality_metric total_audited)"
  [ "$v" = "null" ] && echo 0 || echo "$v"
}

parse_audit_rate() {
  local v
  v="$(parse_quality_metric audit_rate)"
  [ "$v" = "null" ] && echo 0 || echo "$v"
}

parse_max_real_score_audited_skip() {
  local v
  v="$(parse_quality_metric max_real_score_audited_skip)"
  [ "$v" = "null" ] && echo 0 || echo "$v"
}


# M10.99Z216D_DIRECT_SHADOW_SCORE_PARSER
parse_shadow_score_metric() {
  local key="$1"
  local value

  if [ ! -f "$CODED_RUNTIME_LOG" ]; then
    echo 0
    return 0
  fi

  value="$(
    tail -n 300 "$CODED_RUNTIME_LOG" \
      | grep 'FAST_SHADOW_SUMMARY' \
      | grep -E 'total_seen=[1-9][0-9]*' \
      | grep -Eo "${key}=[0-9]+" \
      | tail -1 \
      | cut -d= -f2 || true
  )"

  if [ -z "$value" ]; then
    echo 0
  else
    echo "$value"
  fi
}

# M10.99Z216B_PARSE_SHADOW_SCORE_TELEMETRY
parse_max_shadow_score_seen() {
  parse_shadow_score_metric max_shadow_score_seen
}

parse_max_shadow_score_passed() {
  parse_shadow_score_metric max_shadow_score_passed
}

parse_pass_rate() {
  local v seen pass
  v="$(parse_quality_metric pass_rate)"
  if [ "$v" != "null" ]; then
    echo "$v"
    return 0
  fi

  seen="$(parse_total_seen)"
  pass="$(parse_total_pass)"

  if [ "$seen" = "null" ] || [ "$pass" = "null" ] || [ "$seen" = "0" ]; then
    echo null
    return 0
  fi

  awk -v p="$pass" -v s="$seen" 'BEGIN { printf "%.6f", (p / s) * 100.0 }'
}

parse_avg_its() {
  local v
  v="$(parse_status_avg_its)"
  sanitize_public_its "$v"
}

effective_threads_for_heartbeat() {
  if [ "${THREADS:-0}" != "0" ]; then
    echo "$THREADS"
    return 0
  fi

  if [ "$OS" = "Darwin" ]; then
    sysctl -n hw.ncpu 2>/dev/null || echo 0
    return 0
  fi

  nproc 2>/dev/null || echo 0
}


# M10.99Z217A_MAC_SELF_UPDATE_WATCHDOG
coded_current_release_file() {
  if [ -n "${CODED_CURRENT_RELEASE_FILE:-}" ]; then
    echo "$CODED_CURRENT_RELEASE_FILE"
    return 0
  fi

  if [ -f "${WORKDIR:-/tmp/coded-miner-macos-arm64}/release_manifest.json" ]; then
    # Best effort only. latest-macos-arm64.txt is the source of truth.
    grep -E '"version"' "${WORKDIR:-/tmp/coded-miner-macos-arm64}/release_manifest.json" \
      | head -1 \
      | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || true
  fi
}

coded_latest_release_file() {
  curl -fsSL "$CODED_LATEST_MACOS_ARM64_URL?self_update=$(date +%s)" 2>/dev/null \
    | tr -d '\r\n ' || true
}

start_self_update_watchdog() {
  if [ "${CODED_SELF_UPDATE:-1}" != "1" ]; then
    return 0
  fi

  if [ "${CODED_SELF_UPDATE_STARTED:-0}" = "1" ]; then
    return 0
  fi
  export CODED_SELF_UPDATE_STARTED=1

  (
    sleep "${CODED_SELF_UPDATE_SEC:-60}"

    while true; do
      latest="$(coded_latest_release_file)"
      current="$(coded_current_release_file)"

      if [ -n "$latest" ] && [ -n "$current" ] && [ "$latest" != "$current" ]; then
        echo "[CODED] Update available: current=$current latest=$latest"
        echo "[CODED] Restarting miner to apply latest release..."
        pkill -TERM -f "/tmp/coded-miner-macos-arm64/coded-miner" 2>/dev/null || true
        pkill -TERM -f "coded-miner.*--worker ${WORKER}" 2>/dev/null || true
        sleep 3
        pkill -KILL -f "/tmp/coded-miner-macos-arm64/coded-miner" 2>/dev/null || true
        exit 0
      fi

      sleep "${CODED_SELF_UPDATE_SEC:-60}"
    done
  ) &
}

start_external_fleet_heartbeat() {
  if [ "${CODED_FLEET_JOIN:-YES}" != "YES" ]; then
    return 0
  fi

  if [ "${CODED_FLEET_HEARTBEAT_STARTED:-0}" = "1" ]; then
    return 0
  fi
  export CODED_FLEET_HEARTBEAT_STARTED=1

  DEVICE_ID="${DEVICE_ID:-${CODED_DEVICE_ID:-${CODED_PLATFORM:-unknown}:${WORKER}}}"

  echo "[CODED] Fleet heartbeat: $API_URL/fleet/devices/heartbeat device=$DEVICE_ID"

  (
    while true; do
      curl -fsS -X POST "$API_URL/fleet/devices/heartbeat" \
        -H "Content-Type: application/json" \
        -d "{
          \"device_id\":\"$DEVICE_ID\",
          \"worker_name\":\"$WORKER\",
          \"wallet\":\"$WALLET\",
          \"platform\":\"${CODED_PLATFORM:-unknown}\",
          \"os\":\"$OS\",
          \"arch\":\"$ARCH\",
          \"backend\":\"${CODED_KERNEL_BACKEND:-auto}\",
          \"runtime_mode\":\"${CODED_RUNTIME_MODE:-default_analytics}\",
          \"device_role\":\"${CODED_DEVICE_ROLE:-default_analytics}\",
          \"fullscore\":$(coded_json_bool "${CODED_FORCE_FULLSCORE:-1}"),
          \"CODED_FORCE_FULLSCORE\":\"${CODED_FORCE_FULLSCORE:-1}\",
          \"CODED_FULLSCORE_ALL_BACKENDS\":\"${CODED_FULLSCORE_ALL_BACKENDS:-1}\",
          \"threads\":$(effective_threads_for_heartbeat),
          \"experiment_ready\":$(coded_json_bool "${CODED_EXPERIMENT_READY:-YES}"),
          \"release_build_ready\":$(coded_json_bool "${CODED_RELEASE_BUILD_READY:-YES}"),
          \"runtime_state\":\"$(parse_runtime_state)\",
          \"release_file\":\"${CODED_CURRENT_RELEASE_FILE:-unknown}\",
          \"last_its\":$(parse_last_its),
          \"avg_its\":$(parse_avg_its),
          \"total_seen\":$(parse_total_seen),
          \"total_pass\":$(parse_total_pass),
          \"total_skip\":$(parse_total_skip),
          \"pass_rate\":$(parse_pass_rate),
          \"false_negative\":$(parse_false_negative),
          \"total_audited\":$(parse_total_audited),
          \"audit_rate\":$(parse_audit_rate),
          \"max_real_score_seen\":$(parse_max_real_score_seen),
          \"real_score_available\":$(parse_real_score_available),
          \"max_real_score_passed\":$(parse_max_real_score_passed),
          \"max_real_score_audited_skip\":$(parse_max_real_score_audited_skip),
          \"max_shadow_score_seen\":$(parse_max_shadow_score_seen),
          \"max_shadow_score_passed\":$(parse_max_shadow_score_passed),
          \"started_at\":\"$CODED_STARTED_AT\",
          \"capabilities\":{
            \"scalar\":true,
            \"macos_arm64\":$([ "$OS" = "Darwin" ] && [ "$ARCH" = "arm64" ] && echo true || echo false),
            \"docker\":$([ "${CODED_PLATFORM:-}" = "docker-linux-amd64" ] && echo true || echo false),
            \"build_macos_arm64\":$([ "$OS" = "Darwin" ] && [ "$ARCH" = "arm64" ] && echo true || echo false),
            \"run_experiment\":true,
            \"default_analytics\":true
          }
        }" >/dev/null 2>&1 || true

      sleep "${CODED_FLEET_HEARTBEAT_SEC:-30}"
    done
  ) &
}

echo "[CODED] System: $OS / $ARCH"

if [[ "$OS" == "Darwin" && "$ARCH" == "arm64" ]]; then
  export CODED_PLATFORM="${CODED_PLATFORM:-macos-arm64}"
  export CODED_KERNEL_BACKEND="${CODED_KERNEL_BACKEND:-scalar}"
  export CODED_RELEASE_BUILD_READY="YES"
  export CODED_EXPERIMENT_READY="${CODED_EXPERIMENT_READY:-YES}"
  export CODED_RELEASE_BUILD_READY="YES"

# M10.99Z217A_CAPTURE_CURRENT_RELEASE
if [ -z "${CODED_CURRENT_RELEASE_FILE:-}" ]; then
  CODED_CURRENT_RELEASE_FILE="$(coded_latest_release_file)"
  export CODED_CURRENT_RELEASE_FILE
fi

  start_external_fleet_heartbeat
  echo "[CODED] Using native macOS ARM build"

  WORKDIR="/tmp/coded-miner-macos-arm64"
  # M10.99Z201_VERSIONED_MACOS_ARM_ARTIFACT
  # Prefer a versioned artifact name to avoid GitHub Raw/CDN stale binary cache.
  ARTIFACT="$(curl -fsSL "$BASE_URL/latest-macos-arm64.txt" 2>/dev/null || echo coded-miner-macos-arm64.tar.gz)"

  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR"

  curl -L -o /tmp/$ARTIFACT "$BASE_URL/$ARTIFACT"
  tar -xzf /tmp/$ARTIFACT -C "$WORKDIR"
  # M10.99Z217A_START_SELF_UPDATE_WATCHDOG
  start_self_update_watchdog
  chmod +x "$WORKDIR/coded-miner"

  CODED_ANALYTICS="$CODED_ANALYTICS" \
  CODED_FLEET_JOIN="$CODED_FLEET_JOIN" \
  CODED_FORCE_FULLSCORE="$CODED_FORCE_FULLSCORE" \
  CODED_FULLSCORE_ALL_BACKENDS="$CODED_FULLSCORE_ALL_BACKENDS" \
  CODED_PREFILTER_DIFFICULTY="$CODED_PREFILTER_DIFFICULTY" \
  CODED_KERNEL_BACKEND="$CODED_KERNEL_BACKEND" \
  CODED_PLATFORM="$CODED_PLATFORM" \
  CODED_THREADS="$THREADS" \
  COMMAND_THREADS="$THREADS" \
  CODED_RUNTIME_MODE="$CODED_RUNTIME_MODE" \
  CODED_COMMAND_MODE="$CODED_COMMAND_MODE" \
  CODED_DEVICE_ROLE="$CODED_DEVICE_ROLE" \
  CODED_EXPERIMENT_READY="$CODED_EXPERIMENT_READY" \
  CODED_RELEASE_BUILD_READY="$CODED_RELEASE_BUILD_READY" \
  CODED_CAPABILITIES_UPLOAD="$CODED_CAPABILITIES_UPLOAD" \
  "$WORKDIR/coded-miner" \
    --pool "$POOL" \
    --wallet "$WALLET" \
    --worker "$WORKER" \
    --threads "$THREADS" 2>&1 | tee -a "$CODED_RUNTIME_LOG" | coded_console_filter
  exit ${PIPESTATUS[0]}
fi

start_external_fleet_heartbeat

echo "[CODED] Using Docker amd64 build"

PLATFORM="linux/amd64"
ARTIFACT="coded-miner-docker-linux-amd64.tar.gz"

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] Docker not installed. Please install Docker Desktop first."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  if [[ "$OS" == "Darwin" ]]; then
    echo "[CODED] Starting Docker Desktop..."
    open -a Docker
    until docker info >/dev/null 2>&1; do sleep 2; done
  else
    echo "[ERROR] Docker daemon is not running."
    exit 1
  fi
fi

curl -L -o /tmp/coded-miner-docker.tar.gz "$BASE_URL/$ARTIFACT"
docker load < /tmp/coded-miner-docker.tar.gz

exec docker run --rm \
  --platform "$PLATFORM" \
  -e CODED_ANALYTICS="$CODED_ANALYTICS" \
  -e CODED_FLEET_JOIN="$CODED_FLEET_JOIN" \
  -e CODED_FORCE_FULLSCORE="$CODED_FORCE_FULLSCORE" \
  -e CODED_FULLSCORE_ALL_BACKENDS="$CODED_FULLSCORE_ALL_BACKENDS" \
  -e CODED_PREFILTER_DIFFICULTY="$CODED_PREFILTER_DIFFICULTY" \
  -e CODED_KERNEL_BACKEND="${CODED_KERNEL_BACKEND:-auto}" \
  -e CODED_PLATFORM="${CODED_PLATFORM:-docker-linux-amd64}" \
  -e CODED_THREADS="$THREADS" \
  -e COMMAND_THREADS="$THREADS" \
  -e CODED_RUNTIME_MODE="$CODED_RUNTIME_MODE" \
  -e CODED_COMMAND_MODE="$CODED_COMMAND_MODE" \
  -e CODED_DEVICE_ROLE="$CODED_DEVICE_ROLE" \
  -e CODED_EXPERIMENT_READY="$CODED_EXPERIMENT_READY" \
  -e CODED_RELEASE_BUILD_READY="$CODED_RELEASE_BUILD_READY" \
  -e CODED_CAPABILITIES_UPLOAD="$CODED_CAPABILITIES_UPLOAD" \
  "coded-miner:${VERSION}" \
  --pool "$POOL" \
  --wallet "$WALLET" \
  --worker "$WORKER" \
  --threads "$THREADS"
