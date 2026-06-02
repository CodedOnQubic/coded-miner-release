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
export CODED_RELEASE_BUILD_READY="${CODED_RELEASE_BUILD_READY:-NO}"
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

coded_json_bool() {
  case "$1" in
    YES|yes|true|TRUE|1|ON|on) echo true ;;
    *) echo false ;;
  esac
}

start_external_fleet_heartbeat() {
  if [ "${CODED_FLEET_JOIN:-YES}" != "YES" ]; then
    return 0
  fi

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
          \"threads\":${THREADS:-0},
          \"experiment_ready\":$(coded_json_bool "${CODED_EXPERIMENT_READY:-YES}"),
          \"release_build_ready\":$(coded_json_bool "${CODED_RELEASE_BUILD_READY:-NO}"),
          \"capabilities\":{
            \"scalar\":true,
            \"macos_arm64\":$([ "$OS" = "Darwin" ] && [ "$ARCH" = "arm64" ] && echo true || echo false),
            \"docker\":$([ "${CODED_PLATFORM:-}" = "docker-linux-amd64" ] && echo true || echo false)
          }
        }" >/dev/null 2>&1 || true

      sleep "${CODED_FLEET_HEARTBEAT_SEC:-30}"
    done
  ) &
}


# M10.99Z203A_EXTERNAL_FLEET_HEARTBEAT_FORCE
API_URL="${API_URL:-https://api.codedonqubic.com}"

coded_json_bool() {
  case "$1" in
    YES|yes|true|TRUE|1|ON|on) echo true ;;
    *) echo false ;;
  esac
}

start_external_fleet_heartbeat() {
  if [ "${CODED_FLEET_JOIN:-YES}" != "YES" ]; then
    return 0
  fi

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
          \"threads\":${THREADS:-0},
          \"experiment_ready\":$(coded_json_bool "${CODED_EXPERIMENT_READY:-YES}"),
          \"release_build_ready\":$(coded_json_bool "${CODED_RELEASE_BUILD_READY:-YES}"),
          \"capabilities\":{
            \"scalar\":true,
            \"macos_arm64\":$([ "$OS" = "Darwin" ] && [ "$ARCH" = "arm64" ] && echo true || echo false),
            \"docker\":$([ "${CODED_PLATFORM:-}" = "docker-linux-amd64" ] && echo true || echo false)
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
  export CODED_RELEASE_BUILD_READY="${CODED_RELEASE_BUILD_READY:-YES}"
  start_external_fleet_heartbeat

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
  exec "$WORKDIR/coded-miner" \
    --pool "$POOL" \
    --wallet "$WALLET" \
    --worker "$WORKER" \
    --threads "$THREADS"
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
