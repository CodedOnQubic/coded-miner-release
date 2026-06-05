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

# M10.99Z257_RUNSH_STABLE_EXTERNAL_FLEET_JOIN
# Explicit external fleet onboarding fields.
# This does not touch HiveOS start.sh / h-run.sh.
case "${OS}:${ARCH}" in
  Darwin:arm64) CODED_TARGET="${CODED_TARGET:-macos-arm64}" ;;
  Darwin:x86_64|Darwin:amd64) CODED_TARGET="${CODED_TARGET:-macos-x64}" ;;
  Linux:x86_64|Linux:amd64) CODED_TARGET="${CODED_TARGET:-docker-linux-amd64}" ;;
  MINGW*:x86_64|MSYS*:x86_64|CYGWIN*:x86_64) CODED_TARGET="${CODED_TARGET:-windows-x64}" ;;
  *) CODED_TARGET="${CODED_TARGET:-${OS}-${ARCH}}" ;;
esac

export CODED_TARGET
export CODED_BUILDER="${CODED_BUILDER:-NO}"
export CODED_BUILDER_TARGETS="${CODED_BUILDER_TARGETS:-}"
export CODED_MINER_RUNNING="${CODED_MINER_RUNNING:-false}"

if [ "${CODED_BUILDER}" = "YES" ] || [ "${CODED_BUILDER}" = "yes" ] || [ "${CODED_BUILDER}" = "true" ] || [ "${CODED_BUILDER}" = "1" ]; then
  if [ -z "$CODED_BUILDER_TARGETS" ]; then
    CODED_BUILDER_TARGETS="$CODED_TARGET"
    export CODED_BUILDER_TARGETS
  fi
fi


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

# M10.99Z221F_MACOS_X86_64_RELEASE_SUPPORT
CODED_LATEST_MACOS_X86_64_URL="${CODED_LATEST_MACOS_X86_64_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/latest-macos-x86_64.txt}"
CODED_MACOS_X86_64_RELEASE_BASE_URL="${CODED_MACOS_X86_64_RELEASE_BASE_URL:-https://github.com/CodedOnQubic/coded-miner-release/raw/main}"
export CODED_LATEST_MACOS_X86_64_URL
export CODED_MACOS_X86_64_RELEASE_BASE_URL
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

  echo "[CODED] Fleet supervisor active: worker=${WORKER:-unknown} target=${CODED_TARGET:-unknown} script_check_sec=${CODED_SELF_UPDATE_SEC:-60}"

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

    echo "[CODED] Supervisor: miner child exited, refreshing launcher script before restart..."
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


# M10.99Z257_RUNSH_STABLE_EXTERNAL_FLEET_JOIN
coded_builder_json_array() {
  local raw="${CODED_BUILDER_TARGETS:-}"
  if [ -z "$raw" ]; then
    echo "[]"
    return 0
  fi

  local out="["
  local first=1
  local item
  IFS=',' read -r -a _coded_targets <<< "$raw"
  for item in "${_coded_targets[@]}"; do
    item="$(echo "$item" | sed 's/^ *//;s/ *$//')"
    [ -z "$item" ] && continue
    if [ "$first" -eq 0 ]; then out="$out,"; fi
    out="$out\"$item\""
    first=0
  done
  out="$out]"
  echo "$out"
}

# M10.99Z266D_ROBUST_MINER_RUNNING_HEARTBEAT
# macOS external fleet heartbeat must not rely only on pgrep.
# The miner can be wrapped by supervisor/tee/subshell and pgrep may false-negative.
# Runtime truth for frontend should be true when either process OR fresh runtime log proves mining.
coded_process_running_bool() {
  if pgrep -f "coded-miner" >/dev/null 2>&1; then
    echo true
    return 0
  fi

  if [ -n "${CODED_RUNTIME_LOG:-}" ] && [ -f "$CODED_RUNTIME_LOG" ]; then
    if tail -n 80 "$CODED_RUNTIME_LOG" 2>/dev/null | grep -qE "SOLS:|\[[A-Za-z0-9_-]+\] [0-9.,]+ it/s|\[RUNTIME\] mining active"; then
      echo true
      return 0
    fi
  fi

  local last avg state
  last="$(parse_status_last_its 2>/dev/null || echo 0)"
  avg="$(parse_status_avg_its 2>/dev/null || echo 0)"
  state="$(parse_runtime_state 2>/dev/null || echo "")"

  if [ "$state" = "mining_active" ]; then
    echo true
    return 0
  fi

  awk -v last="$last" -v avg="$avg" 'BEGIN {
    if ((last+0) > 0 || (avg+0) > 0) print "true";
    else print "false";
  }'
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

# M10.99Z221C_PARSE_BACKEND_CONTRACT_FIELDS
parse_quality_string_metric() {
  key="$1"
  if [ -z "${LOG_FILE:-}" ] && [ -n "${WORKER:-}" ]; then
    LOG_FILE="/tmp/coded-miner-${WORKER}.log"
  fi
  if [ ! -f "${LOG_FILE:-/dev/null}" ]; then
    echo ""
    return 0
  fi
  grep "FAST_SHADOW_SUMMARY" "$LOG_FILE" 2>/dev/null \
    | tail -n 1 \
    | tr ' ' '\n' \
    | grep -E "^${key}=" \
    | tail -n 1 \
    | cut -d= -f2- \
    | tr -d '\r\n' || true
}

parse_backend_kind() {
  v="$(parse_quality_string_metric backend_kind)"
  [ -n "$v" ] && echo "$v" || echo ""
}

parse_backend_short() {
  v="$(parse_quality_string_metric backend_short)"
  [ -n "$v" ] && echo "$v" || echo ""
}

parse_backend_platform() {
  v="$(parse_quality_string_metric backend_platform)"
  [ -n "$v" ] && echo "$v" || echo "${CODED_PLATFORM:-}"
}

parse_backend_validation() {
  v="$(parse_quality_string_metric backend_validation)"
  [ -n "$v" ] && echo "$v" || echo ""
}

parse_real_score_authoritative() {
  v="$(parse_quality_metric real_score_authoritative)"
  [ "$v" = "null" ] && echo 0 || echo "$v"
}

parse_gpu_accelerated() {
  v="$(parse_quality_metric gpu_accelerated)"
  [ "$v" = "null" ] && echo 0 || echo "$v"
}

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
  # M10.99Z221F_PLATFORM_AWARE_LATEST_RELEASE
  if [ "${CODED_PLATFORM:-}" = "macos-x86_64" ] || { [ "$(uname -s 2>/dev/null || true)" = "Darwin" ] && [ "$(uname -m 2>/dev/null || true)" = "x86_64" ]; }; then
    curl -fsSL "$CODED_LATEST_MACOS_X86_64_URL?self_update=$(date +%s)" 2>/dev/null \
      | tr -d '\r\n ' || true
    return 0
  fi

  curl -fsSL "${CODED_LATEST_MACOS_ARM64_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/latest-macos-arm64.txt}?self_update=$(date +%s)" 2>/dev/null \
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


# M10.99Z221F_X86_64_DOWNLOAD_OVERRIDE
coded_download_url_for_current_platform() {
  if [ "${CODED_PLATFORM:-}" = "macos-x86_64" ]; then
    latest="$(coded_latest_release_file)"
    if [ -n "$latest" ]; then
      echo "$CODED_MACOS_X86_64_RELEASE_BASE_URL/$latest"
      return 0
    fi
    echo "$CODED_MACOS_X86_64_RELEASE_BASE_URL/coded-miner-macos-x86_64.tar.gz"
    return 0
  fi

  if [ -n "${CODED_TARBALL_URL:-}" ]; then
    echo "$CODED_TARBALL_URL"
    return 0
  fi

  # M10.99Z268G2_ARM_RELEASE_LATEST_DOWNLOAD_URL
  # macOS ARM must consume the GitHub Release latest asset produced by Primary publisher,
  # not the raw main branch file.
  echo "${CODED_MACOS_ARM64_TARBALL_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64.tar.gz}"
}


# M10.99Z265A_EXTERNAL_BUILD_AGENT_STUB_SAFE
# External build agent lifecycle stub.
# Safe contract:
# - Does not touch Hive start.sh / h-run.sh.
# - Does not publish artifacts.
# - Does not replace ARM fullscore backend.
# - Only validates external builder lifecycle: next -> running -> complete/fail -> default resume.
coded_z265a_urlencode() {
  python3 - "$1" <<'PYURL' 2>/dev/null || printf "%s" "$1"
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1], safe=""))
PYURL
}

# M10.99Z265B_EXTERNAL_BUILD_AGENT_JSON_FIX
# Important: do not use a Python heredoc here, because the function receives JSON on stdin.
coded_z265a_json_get() {
  local key="$1"
  python3 -c '
import sys, json
key=sys.argv[1]
try:
    raw=sys.stdin.read()
    if not raw.strip():
        print("")
        raise SystemExit(0)
    j=json.loads(raw)
    cur=j
    for part in key.split("."):
        if isinstance(cur, dict):
            cur=cur.get(part)
        else:
            cur=None
            break
    if cur is None:
        print("")
    elif isinstance(cur, (dict, list)):
        print(json.dumps(cur, separators=(",",":")))
    else:
        print(str(cur))
except Exception:
    print("")
' "$key" 2>/dev/null || true
}

# M10.99Z265B_EXTERNAL_BUILD_AGENT_JSON_FIX
coded_z265a_post_json() {
  local path="$1"
  local body="$2"
  local out code
  out="$(curl -sS -w "\nHTTP_CODE:%{http_code}" -X POST "$API_URL$path" \
    -H "Content-Type: application/json" \
    -d "$body" 2>&1 || true)"
  code="$(printf "%s\n" "$out" | grep 'HTTP_CODE:' | tail -1 | cut -d: -f2 || true)"
  out="$(printf "%s\n" "$out" | sed '/HTTP_CODE:/d' || true)"

  if [ "$code" != "200" ] && [ "$code" != "201" ]; then
    echo "[M10.99Z265B_EXTERNAL_BUILD_AGENT_JSON_FIX] POST failed path=$path http=$code response=$out"
    return 1
  fi

  echo "[M10.99Z265B_EXTERNAL_BUILD_AGENT_JSON_FIX] POST ok path=$path http=$code"
  return 0
}


# M10.99Z266B_EXTERNAL_BUILD_ARTIFACT_UPLOAD
coded_z266b_upload_artifact_to_primary() {
  local cmd_id="$1"
  local artifact_path="$2"
  local target="$3"
  local version="$4"
  local artifact_name="$5"
  local sha256="$6"
  local publish_ready="${7:-false}"

  if [ -z "$cmd_id" ] || [ -z "$artifact_path" ] || [ ! -f "$artifact_path" ]; then
    echo "[M10.99Z266B_EXTERNAL_BUILD_ARTIFACT_UPLOAD] skip missing artifact cmd=$cmd_id path=$artifact_path"
    return 1
  fi

  local b64 payload tmp_payload code out
  b64="$(base64 < "$artifact_path" | tr -d '\n')"
  tmp_payload="/tmp/coded-z266b-upload-${cmd_id}.json"

  cat > "$tmp_payload" <<EOF
{
  "target":"$target",
  "version":"$version",
  "artifact_name":"$artifact_name",
  "artifact_sha256":"$sha256",
  "publish_ready":$publish_ready,
  "artifact_base64":"$b64"
}
EOF

  out="$(curl -sS -w "\nHTTP_CODE:%{http_code}" -X POST "$API_URL/fleet/external-build/$cmd_id/artifact" \
    -H "Content-Type: application/json" \
    --data-binary "@$tmp_payload" 2>&1 || true)"

  code="$(printf "%s\n" "$out" | grep 'HTTP_CODE:' | tail -1 | cut -d: -f2 || true)"
  out="$(printf "%s\n" "$out" | sed '/HTTP_CODE:/d' || true)"

  rm -f "$tmp_payload" >/dev/null 2>&1 || true

  if [ "$code" != "200" ] && [ "$code" != "201" ]; then
    echo "[M10.99Z266B_EXTERNAL_BUILD_ARTIFACT_UPLOAD] upload failed cmd=$cmd_id http=$code response=$out"
    return 1
  fi

  echo "[M10.99Z266B_EXTERNAL_BUILD_ARTIFACT_UPLOAD] upload ok cmd=$cmd_id http=$code"
  return 0
}

coded_z265a_make_stub_artifact() {
  local cmd_json="$1"
  local command_id version target artifact_name out_dir payload_dir artifact_path manifest_path expected_commit

  command_id="$(printf "%s" "$cmd_json" | coded_z265a_json_get "command.command_id")"
  version="$(printf "%s" "$cmd_json" | coded_z265a_json_get "command.params.version")"
  target="$(printf "%s" "$cmd_json" | coded_z265a_json_get "command.target")"
  artifact_name="$(printf "%s" "$cmd_json" | coded_z265a_json_get "command.params.artifact_name")"
  expected_commit="$(printf "%s" "$cmd_json" | coded_z265a_json_get "command.params.expected_commit")"

  [ -z "$command_id" ] && return 1
  [ -z "$version" ] && version="v0.0.0-z265a-stub"
  [ -z "$target" ] && target="${CODED_TARGET:-unknown}"
  [ -z "$artifact_name" ] && artifact_name="coded-miner-${target}-${version}.tar.gz"

  out_dir="/tmp/coded-external-build-${command_id}"
  payload_dir="$out_dir/payload"
  artifact_path="$out_dir/$artifact_name"
  manifest_path="$payload_dir/release_manifest.json"

  rm -rf "$out_dir"
  mkdir -p "$payload_dir"

  cat > "$manifest_path" <<EOF
{
  "version": "$version",
  "target": "$target",
  "platform": "${CODED_PLATFORM:-unknown}",
  "arch": "$ARCH",
  "repo": "CodedOnQubic/coded-miner",
  "branch": "main",
  "commit": "$expected_commit",
  "built_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "builder_device_id": "${DEVICE_ID:-unknown}",
  "builder_worker": "${WORKER:-unknown}",
  "marker": "M10.99Z265A_EXTERNAL_BUILD_AGENT_STUB_SAFE",
  "stub": true,
  "publish_ready": false
}
EOF

  cat > "$payload_dir/README_Z265A_STUB.txt" <<EOF
M10.99Z265A_EXTERNAL_BUILD_AGENT_STUB_SAFE

This artifact validates the external Fleet builder lifecycle only.
It is not a production miner artifact.
It must not replace the real ARM fullscore backend artifact.
EOF

  tar -czf "$artifact_path" -C "$payload_dir" .

  printf "%s" "$artifact_path"
}


# M10.99Z267A_EXTERNAL_MAC_ARM_REALSCORE_BUILD
# M10.99Z267C_STDOUT_CLEAN_REAL_ARM_ARTIFACT_PATH
# IMPORTANT: this function is called via command substitution. Only final artifact path may go to stdout.
coded_z267a_make_real_macos_arm_artifact() {
  local cmd_json="$1"
  local command_id version target artifact_name expected_commit repo branch out_dir src_dir build_dir payload_dir artifact_path manifest_path bin_path

  command_id="$(printf "%s" "$cmd_json" | coded_z265a_json_get "command.command_id")"
  version="$(printf "%s" "$cmd_json" | coded_z265a_json_get "command.params.version")"
  target="$(printf "%s" "$cmd_json" | coded_z265a_json_get "command.target")"
  artifact_name="$(printf "%s" "$cmd_json" | coded_z265a_json_get "command.params.artifact_name")"
  expected_commit="$(printf "%s" "$cmd_json" | coded_z265a_json_get "command.params.expected_commit")"
  repo="$(printf "%s" "$cmd_json" | coded_z265a_json_get "command.params.repo")"
  branch="$(printf "%s" "$cmd_json" | coded_z265a_json_get "command.params.branch")"

  [ -z "$command_id" ] && return 1
  [ -z "$version" ] && version="v0.0.0-z267a-arm-realscore"
  [ -z "$target" ] && target="macos-arm64"
  [ -z "$artifact_name" ] && artifact_name="coded-miner-${target}-${version}.tar.gz"
  [ -z "$repo" ] && repo="CodedOnQubic/coded-miner"
  [ -z "$branch" ] && branch="z242-arm-hotpath-contract-clean"

  if [ "$target" != "macos-arm64" ]; then
    echo "[M10.99Z267A_EXTERNAL_MAC_ARM_REALSCORE_BUILD] wrong target=$target" >&2
    return 1
  fi

  out_dir="/tmp/coded-external-build-${command_id}"
  src_dir="$out_dir/src"
  build_dir="$out_dir/build"
  payload_dir="$out_dir/payload"
  artifact_path="$out_dir/$artifact_name"
  manifest_path="$payload_dir/release_manifest.json"

  rm -rf "$out_dir"
  mkdir -p "$src_dir" "$build_dir" "$payload_dir"

  echo "[M10.99Z267A_EXTERNAL_MAC_ARM_REALSCORE_BUILD] clone repo=$repo branch=$branch expected_commit=$expected_commit" >&2

  if ! git clone --depth 80 --branch "$branch" "https://github.com/${repo}.git" "$src_dir"; then
    echo "[M10.99Z267A_EXTERNAL_MAC_ARM_REALSCORE_BUILD] git clone failed" >&2
    return 1
  fi

  cd "$src_dir" || return 1

  if [ -n "$expected_commit" ]; then
    git fetch --depth 80 origin "$expected_commit" >/dev/null 2>&1 || true
    if ! git checkout "$expected_commit"; then
      echo "[M10.99Z267A_EXTERNAL_MAC_ARM_REALSCORE_BUILD] expected_commit checkout failed: $expected_commit" >&2
      return 1
    fi
  fi

  local actual_commit
  actual_commit="$(git rev-parse HEAD 2>/dev/null || true)"

  echo "[M10.99Z267A_EXTERNAL_MAC_ARM_REALSCORE_BUILD] actual_commit=$actual_commit" >&2

  if [ -n "$expected_commit" ]; then
    case "$actual_commit" in
      "$expected_commit"*) ;;
      *)
        echo "[M10.99Z267A_EXTERNAL_MAC_ARM_REALSCORE_BUILD] commit mismatch expected=$expected_commit actual=$actual_commit" >&2
        return 1
        ;;
    esac
  fi

  echo "[M10.99Z267A_EXTERNAL_MAC_ARM_REALSCORE_BUILD] cmake configure/build" >&2

  if command -v cmake >/dev/null 2>&1; then
    cmake -S "$src_dir" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release >&2
    cmake --build "$build_dir" --config Release -j "$(sysctl -n hw.ncpu 2>/dev/null || echo 4)" >&2
  else
    echo "[M10.99Z267A_EXTERNAL_MAC_ARM_REALSCORE_BUILD] cmake missing" >&2
    return 1
  fi

  # M10.99Z267B_ROBUST_REAL_ARM_BINARY_FIND
  # macOS/BSD find can be picky with -perm syntax. Prefer deterministic candidates,
  # then fall back to name search and chmod validation.
  bin_path=""
  for candidate in \
    "$build_dir/coded-miner" \
    "$build_dir/src/coded-miner" \
    "$build_dir/bin/coded-miner" \
    "$src_dir/coded-miner" \
    "$src_dir/build/coded-miner" \
    "$src_dir/build/src/coded-miner"
  do
    if [ -f "$candidate" ]; then
      bin_path="$candidate"
      break
    fi
  done

  if [ -z "$bin_path" ]; then
    bin_path="$(find "$build_dir" "$src_dir" -type f \( -name coded-miner -o -name coded-miner-arm64 -o -name 'coded-miner*' \) 2>/dev/null | head -1 || true)"
  fi

  if [ -z "$bin_path" ] || [ ! -f "$bin_path" ]; then
    echo "[M10.99Z267B_ROBUST_REAL_ARM_BINARY_FIND] coded-miner binary not found" >&2
    echo "[M10.99Z267B_ROBUST_REAL_ARM_BINARY_FIND] build_dir=$build_dir src_dir=$src_dir" >&2
    find "$build_dir" -maxdepth 5 -type f | sed -n '1,120p' >&2 || true
    return 1
  fi

  chmod +x "$bin_path" >/dev/null 2>&1 || true

  if [ ! -x "$bin_path" ]; then
    echo "[M10.99Z267B_ROBUST_REAL_ARM_BINARY_FIND] binary exists but is not executable: $bin_path" >&2
    ls -lah "$bin_path" >&2 || true
    return 1
  fi

  echo "[M10.99Z267B_ROBUST_REAL_ARM_BINARY_FIND] binary=$bin_path" >&2

  cp "$bin_path" "$payload_dir/coded-miner"
  chmod +x "$payload_dir/coded-miner"

  cat > "$manifest_path" <<EOF
{
  "version": "$version",
  "target": "macos-arm64",
  "platform": "macos-arm64",
  "arch": "arm64",
  "repo": "$repo",
  "branch": "$branch",
  "commit": "$actual_commit",
  "built_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "builder_device_id": "${DEVICE_ID:-unknown}",
  "builder_worker": "${WORKER:-unknown}",
  "marker": "M10.99Z267A_EXTERNAL_MAC_ARM_REALSCORE_BUILD",
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
EOF

  tar -czf "$artifact_path" -C "$payload_dir" .

  echo "[M10.99Z267A_EXTERNAL_MAC_ARM_REALSCORE_BUILD] artifact=$artifact_path" >&2
  printf "%s" "$artifact_path"
}

coded_external_build_agent_loop() {
  if [ "${CODED_EXTERNAL_BUILD_AGENT:-YES}" != "YES" ]; then
    return 0
  fi

  if [ "${CODED_EXTERNAL_BUILD_AGENT_STARTED:-0}" = "1" ]; then
    return 0
  fi
  export CODED_EXTERNAL_BUILD_AGENT_STARTED=1

  DEVICE_ID="${DEVICE_ID:-${CODED_DEVICE_ID:-${CODED_TARGET:-${CODED_PLATFORM:-unknown}}:${WORKER}}}"
  local encoded_device
  encoded_device="$(coded_z265a_urlencode "$DEVICE_ID")"

  echo "[CODED] External build agent active: device=$DEVICE_ID target=${CODED_TARGET:-unknown} poll_sec=${CODED_EXTERNAL_BUILD_POLL_SEC:-20}"

  (
    while true; do
      sleep "${CODED_EXTERNAL_BUILD_POLL_SEC:-20}"

      RESP="$(curl -fsS "$API_URL/fleet/external-build/next/$encoded_device" 2>/dev/null || true)"
      [ -z "$RESP" ] && continue

      CMD_ID="$(printf "%s" "$RESP" | coded_z265a_json_get "command.command_id")"
      TARGET="$(printf "%s" "$RESP" | coded_z265a_json_get "command.target")"

      if [ -z "$CMD_ID" ]; then
        echo "[M10.99Z265B_EXTERNAL_BUILD_AGENT_JSON_FIX] no command_id parsed from /next response; response=$(printf "%s" "$RESP" | head -c 500)"
        continue
      fi

      echo "[M10.99Z265A_EXTERNAL_BUILD_AGENT_STUB_SAFE] picked command=$CMD_ID target=$TARGET"

      if ! coded_z265a_post_json "/fleet/external-build/$CMD_ID/running" "{
        \"result\":{
          \"marker\":\"M10.99Z265B_EXTERNAL_BUILD_AGENT_RUNNING\",
          \"device_id\":\"$DEVICE_ID\",
          \"worker\":\"${WORKER:-unknown}\",
          \"target\":\"$TARGET\"
        }
      }"; then
        coded_z265a_post_json "/fleet/external-build/$CMD_ID/fail" "{
          \"error\":\"Z265B failed to mark external build command running\",
          \"result\":{
            \"marker\":\"M10.99Z265B_EXTERNAL_BUILD_AGENT_RUNNING_FAILED\",
            \"status\":\"safe_failed_before_build\",
            \"device_id\":\"$DEVICE_ID\",
            \"target\":\"$TARGET\"
          }
        }" || true
        continue
      fi

      if [ "${CODED_EXTERNAL_BUILD_STOP_MINER:-YES}" = "YES" ]; then
        echo "[M10.99Z265A_EXTERNAL_BUILD_AGENT_STUB_SAFE] stopping miner for build window command=$CMD_ID"
        pkill -f "/coded-miner" >/dev/null 2>&1 || true
        pkill -f "coded-miner " >/dev/null 2>&1 || true
      fi

      PUBLISH_READY="false"
      BUILD_KIND="stub"

      if [ "${CODED_EXTERNAL_REAL_BUILD:-NO}" = "YES" ] && [ "$TARGET" = "macos-arm64" ]; then
        echo "[M10.99Z267A_EXTERNAL_MAC_ARM_REALSCORE_BUILD] real build enabled command=$CMD_ID"
        ARTIFACT_PATH="$(coded_z267a_make_real_macos_arm_artifact "$RESP" || true)"
        if [ -n "$ARTIFACT_PATH" ] && [ -f "$ARTIFACT_PATH" ]; then
          PUBLISH_READY="true"
          BUILD_KIND="real_arm_realscore"
        fi
      else
        ARTIFACT_PATH="$(coded_z265a_make_stub_artifact "$RESP" || true)"
      fi

      if [ -n "$ARTIFACT_PATH" ] && [ -f "$ARTIFACT_PATH" ]; then
        SHA256="$(shasum -a 256 "$ARTIFACT_PATH" 2>/dev/null | awk '{print $1}' || true)"
        SIZE="$(wc -c < "$ARTIFACT_PATH" 2>/dev/null | tr -d ' ' || true)"

        VERSION="$(printf "%s" "$RESP" | coded_z265a_json_get "command.params.version")"
        ARTIFACT_NAME="$(printf "%s" "$RESP" | coded_z265a_json_get "command.params.artifact_name")"

        # M10.99Z267D_STRICT_REAL_ARM_UPLOAD_BEFORE_COMPLETE
        # Real publishable ARM builds must not complete unless Primary artifact upload succeeds.
        UPLOAD_OK="false"
        if coded_z266b_upload_artifact_to_primary "$CMD_ID" "$ARTIFACT_PATH" "$TARGET" "$VERSION" "$ARTIFACT_NAME" "$SHA256" "$PUBLISH_READY"; then
          UPLOAD_OK="true"
        fi

        if [ "$PUBLISH_READY" = "true" ] && [ "$UPLOAD_OK" != "true" ]; then
          coded_z265a_post_json "/fleet/external-build/$CMD_ID/fail" "{
            \"error\":\"Z267D real ARM artifact upload to Primary failed\",
            \"result\":{
              \"marker\":\"M10.99Z267D_STRICT_REAL_ARM_UPLOAD_BEFORE_COMPLETE\",
              \"status\":\"real_arm_upload_failed\",
              \"device_id\":\"$DEVICE_ID\",
              \"worker\":\"${WORKER:-unknown}\",
              \"target\":\"$TARGET\",
              \"artifact_path\":\"$ARTIFACT_PATH\",
              \"artifact_sha256\":\"$SHA256\"
            }
          }" || true
          continue
        fi

        coded_z265a_post_json "/fleet/external-build/$CMD_ID/complete" "{
          \"result\":{
            \"marker\":\"M10.99Z265B_EXTERNAL_BUILD_AGENT_STUB_COMPLETED\",
            \"handoff_marker\":\"M10.99Z266B_EXTERNAL_BUILD_ARTIFACT_UPLOAD\",
            \"status\":\"${BUILD_KIND}_build_completed\",
            \"device_id\":\"$DEVICE_ID\",
            \"worker\":\"${WORKER:-unknown}\",
            \"target\":\"$TARGET\",
            \"artifact_path\":\"$ARTIFACT_PATH\",
            \"artifact_sha256\":\"$SHA256\",
            \"artifact_size_bytes\":\"$SIZE\",
            \"resume_default_after\":true,
            \"publish_ready\":$PUBLISH_READY,\n            \"upload_ok\":$UPLOAD_OK,
            \"complete_marker\":\"M10.99Z267E_COMPLETE_RESULT_PUBLISH_READY\"
          }
        }"

        echo "[M10.99Z265A_EXTERNAL_BUILD_AGENT_STUB_SAFE] completed command=$CMD_ID artifact=$ARTIFACT_PATH"
      else
        coded_z265a_post_json "/fleet/external-build/$CMD_ID/fail" "{
          \"error\":\"Z265A stub artifact creation failed\",
          \"result\":{
            \"marker\":\"M10.99Z265B_EXTERNAL_BUILD_AGENT_STUB_FAILED\",
            \"status\":\"stub_build_failed\",
            \"device_id\":\"$DEVICE_ID\",
            \"target\":\"$TARGET\"
          }
        }"

        echo "[M10.99Z265A_EXTERNAL_BUILD_AGENT_STUB_SAFE] failed command=$CMD_ID"
      fi

      if [ "${CODED_EXTERNAL_BUILD_STOP_MINER:-YES}" = "YES" ]; then
        echo "[M10.99Z265A_EXTERNAL_BUILD_AGENT_STUB_SAFE] build window finished; exiting child so supervisor resumes default mining"
        exit 0
      fi
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

  echo "[CODED] Fleet heartbeat: $API_URL/fleet/devices/heartbeat device=$DEVICE_ID target=${CODED_TARGET:-unknown} builder=${CODED_BUILDER:-NO} builder_targets=${CODED_BUILDER_TARGETS:-}"

  (
    while true; do
      # M10.99Z257B_RUNSH_EXPLICIT_FLEET_HEARTBEAT_FIELDS
      curl -fsS -X POST "$API_URL/fleet/devices/heartbeat" \
        -H "Content-Type: application/json" \
        -d "{
          \"device_id\":\"$DEVICE_ID\",
          \"worker_name\":\"$WORKER\",
          \"wallet\":\"$WALLET\",

          \"target\":\"${CODED_TARGET:-unknown}\",
          \"analytics\":$(coded_json_bool "${CODED_ANALYTICS:-YES}"),
          \"builder\":$(coded_json_bool "${CODED_BUILDER:-NO}"),
          \"builder_targets\":$(coded_builder_json_array),
          \"miner_running\":$(coded_process_running_bool),

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
          \"backend_kind\":\"$(parse_backend_kind)\",
          \"backend_short\":\"$(parse_backend_short)\",
          \"backend_platform\":\"$(parse_backend_platform)\",
          \"backend_validation\":\"$(parse_backend_validation)\",
          \"real_score_authoritative\":$(parse_real_score_authoritative),
          \"gpu_accelerated\":$(parse_gpu_accelerated),
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


# M10.99Z221F_PLATFORM_NORMALIZE
if [ "$(uname -s 2>/dev/null || true)" = "Darwin" ] && [ "$(uname -m 2>/dev/null || true)" = "x86_64" ]; then
  CODED_PLATFORM="${CODED_PLATFORM:-macos-x86_64}"
  CODED_BACKEND_LABEL="${CODED_BACKEND_LABEL:-avx2}"
  WORKDIR="${WORKDIR:-/tmp/coded-miner-macos-x86_64}"
  TARBALL="${TARBALL:-/tmp/coded-miner-macos-x86_64.tar.gz}"
  export CODED_PLATFORM CODED_BACKEND_LABEL WORKDIR TARBALL
fi

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
  coded_external_build_agent_loop
  if [ "${CODED_PLATFORM:-}" = "macos-x86_64" ]; then
  echo "[CODED] Using native macOS Intel x86_64 build"
else
  echo "[CODED] Using native macOS ARM build"
fi

  WORKDIR="/tmp/coded-miner-macos-arm64"

  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR"

  # M10.99Z268H3_ARM_INSTALL_RELEASE_LATEST_DIRECT
  # macOS ARM must install the GitHub Release latest asset, not raw/main latest-macos-arm64.txt.
  DOWNLOAD_URL="$(coded_download_url_for_current_platform)"
  echo "[CODED] macOS ARM release download url: $DOWNLOAD_URL"
  curl -fL -o "$WORKDIR/coded-miner.tar.gz" "$DOWNLOAD_URL"

  tar -xzf "$WORKDIR/coded-miner.tar.gz" -C "$WORKDIR"
  # M10.99Z217A_START_SELF_UPDATE_WATCHDOG
  start_self_update_watchdog
  chmod +x "$WORKDIR/coded-miner"

  if [ -f "$WORKDIR/release_manifest.json" ]; then
    echo "[CODED] macOS ARM installed manifest:"
    cat "$WORKDIR/release_manifest.json" | sed -n '1,100p'
  fi

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
