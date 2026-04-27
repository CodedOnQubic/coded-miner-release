#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-v0.1.0}"
POOL="${POOL:-pool.codedonqubic.com:7777}"
WALLET="${WALLET:-}"
WORKER="${WORKER:-coded-mac}"
THREADS="${THREADS:-4}"

BASE_URL="https://github.com/CodedOnQubic/coded-miner-release/raw/main"

if [ -z "$WALLET" ]; then
  echo "[ERROR] WALLET missing"
  echo "Usage:"
  echo 'WALLET=YOUR_WALLET WORKER=my-mac bash -c "$(curl -fsSL https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh)"'
  exit 1
fi

OS="$(uname -s)"
ARCH="$(uname -m)"

echo "[CODED] System: $OS / $ARCH"

if [[ "$OS" == "Darwin" && "$ARCH" == "arm64" ]]; then
  echo "[CODED] Using native macOS ARM build"

  WORKDIR="/tmp/coded-miner-macos-arm64"
  ARTIFACT="coded-miner-macos-arm64.tar.gz"

  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR"

  curl -L -o /tmp/$ARTIFACT "$BASE_URL/$ARTIFACT"
  tar -xzf /tmp/$ARTIFACT -C "$WORKDIR"
  chmod +x "$WORKDIR/coded-miner"

  exec "$WORKDIR/coded-miner" \
    --pool "$POOL" \
    --wallet "$WALLET" \
    --worker "$WORKER" \
    --threads "$THREADS"
fi

echo "[CODED] Using Docker amd64 build"

PLATFORM="linux/amd64"
ARTIFACT="coded-miner-docker-${VERSION}-linux-amd64.tar.gz"

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
  "coded-miner:${VERSION}" \
  --pool "$POOL" \
  --wallet "$WALLET" \
  --worker "$WORKER" \
  --threads "$THREADS"
