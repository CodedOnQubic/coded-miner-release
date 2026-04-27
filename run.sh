#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-v0.1.0}"
POOL="${POOL:-pool.codedonqubic.com:7777}"
WALLET="${WALLET:-}"
WORKER="${WORKER:-coded-docker}"
THREADS="${THREADS:-4}"

if [ -z "$WALLET" ]; then
  echo "[ERROR] WALLET missing"
  echo "Usage:"
  echo "WALLET=YOUR_WALLET WORKER=my-mac bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)\""
  exit 1
fi

OS="$(uname -s)"
ARCH="$(uname -m)"

PLATFORM="linux/amd64"
ARTIFACT="coded-miner-docker-${VERSION}-linux-amd64.tar.gz"

if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
  # currently use amd64 via Docker emulation until native arm64 image exists
  PLATFORM="linux/amd64"
  ARTIFACT="coded-miner-docker-${VERSION}-linux-amd64.tar.gz"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] Docker not installed. Please install Docker Desktop first."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  if [ "$OS" = "Darwin" ]; then
    echo "[CODED] Starting Docker Desktop..."
    open -a Docker
    until docker info >/dev/null 2>&1; do sleep 2; done
  else
    echo "[ERROR] Docker daemon is not running."
    exit 1
  fi
fi

echo "[CODED] System: $OS / $ARCH"
echo "[CODED] Using platform: $PLATFORM"
echo "[CODED] Downloading: $ARTIFACT"

curl -L -o /tmp/coded-miner-docker.tar.gz \
  "https://github.com/CodedOnQubic/coded-miner-release/raw/main/${ARTIFACT}"

docker load < /tmp/coded-miner-docker.tar.gz

echo "[CODED] Starting miner..."
docker run --rm \
  --platform "$PLATFORM" \
  "coded-miner:${VERSION}" \
  --pool "$POOL" \
  --wallet "$WALLET" \
  --worker "$WORKER" \
  --threads "$THREADS"
