#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-v0.1.0}"
POOL="${POOL:-pool.codedonqubic.com:7777}"
WALLET="${WALLET:-}"
WORKER="${WORKER:-coded-mac}"
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

# 👉 später hier arm64 hinzufügen
if [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
  PLATFORM="linux/amd64"
fi

echo "[CODED] System: $OS / $ARCH"

# =========================
# DOCKER INSTALL (MAC)
# =========================
if ! command -v docker >/dev/null 2>&1; then
  if [[ "$OS" == "Darwin" ]]; then
    echo "[CODED] Installing Docker Desktop..."

    curl -L -o /tmp/Docker.dmg https://desktop.docker.com/mac/main/arm64/Docker.dmg || \
    curl -L -o /tmp/Docker.dmg https://desktop.docker.com/mac/main/amd64/Docker.dmg

    hdiutil attach /tmp/Docker.dmg
    cp -R "/Volumes/Docker/Docker.app" /Applications
    hdiutil detach "/Volumes/Docker"

    echo "[CODED] Docker installed."
  else
    echo "[ERROR] Docker not installed"
    exit 1
  fi
fi

# =========================
# START DOCKER
# =========================
if ! docker info >/dev/null 2>&1; then
  if [[ "$OS" == "Darwin" ]]; then
    echo "[CODED] Starting Docker..."
    open -a Docker

    echo "[CODED] Waiting for Docker..."
    until docker info >/dev/null 2>&1; do sleep 2; done
  else
    echo "[ERROR] Docker daemon not running"
    exit 1
  fi
fi

# =========================
# DOWNLOAD + RUN
# =========================
echo "[CODED] Downloading miner..."

curl -L -o /tmp/coded-miner.tar.gz \
  "https://github.com/CodedOnQubic/coded-miner-release/raw/main/${ARTIFACT}"

echo "[CODED] Loading image..."
docker load < /tmp/coded-miner.tar.gz

echo "[CODED] Starting miner..."

docker run --rm \
  --platform "$PLATFORM" \
  coded-miner:${VERSION} \
  --pool "$POOL" \
  --wallet "$WALLET" \
  --worker "$WORKER" \
  --threads "$THREADS"
