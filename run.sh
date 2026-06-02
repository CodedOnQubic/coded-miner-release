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

  if [ "$(parse_last_its)" != "0" ] || [ "$(parse_avg_its)" != "0" ]; then
    echo "mining_active"
    return 0
  fi

  echo "running"
}

parse_last_its() {
  if [ ! -f "$CODED_RUNTIME_LOG" ]; then
    echo 0
    return 0
  fi

  local value
  value="$(tail -n 200 "$CODED_RUNTIME_LOG" \
    | grep -Eo '\[[A-Za-z0-9_-]+\] [0-9.,]+ it/s' \
    | tail -1 \
    | awk '{print $(NF-1)}' \
    | tr -d ',.' || true)"

  if [ -n "$value" ] && [ "$value" != "000" ]; then
    echo "$value"
    return 0
  fi

  compute_hi_timing_its
}

parse_avg_its() {
  if [ ! -f "$CODED_RUNTIME_LOG" ]; then
    echo 0
    return 0
  fi

  local value
  value="$(tail -n 200 "$CODED_RUNTIME_LOG" \
    | grep -Eo '[0-9.,]+ avg it/s' \
    | tail -1 \
    | awk '{print $1}' \
    | tr -d ',.' || true)"

  if [ -n "$value" ] && [ "$value" != "000" ]; then
    echo "$value"
    return 0
  fi

  if [ -f "$CODED_HI_METRICS_CACHE" ]; then
    cat "$CODED_HI_METRICS_CACHE"
    return 0
  fi

  compute_hi_timing_its
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
          \"last_its\":$(parse_last_its),
          \"avg_its\":$(parse_avg_its),
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
    --threads "$THREADS" 2>&1 | tee -a "$CODED_RUNTIME_LOG"
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
