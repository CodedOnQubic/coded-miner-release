#!/usr/bin/env bash
set -euo pipefail

echo "[CODED] killing old processes..."
pkill -f coded-miner || true

echo "[CODED] CLEAN + REINSTALL START"

MINER_DIR="/hive/miners/custom/coded-miner"
TMP_TAR="/hive/coded-miner-latest.tar.gz"
INSTALL_URL="https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest.tar.gz"

echo "[CODED] stopping miner..."
miner stop || true

echo "[CODED] removing old miner..."
rm -rf "$MINER_DIR"
rm -f "$TMP_TAR"
rm -f /hive/miners/custom/coded-miner-latest.tar.gz

echo "[CODED] downloading latest release..."
cd /hive
wget -q -O "$TMP_TAR" "$INSTALL_URL"

echo "[CODED] extracting..."
mkdir -p /hive/miners/custom
tar -xzf "$TMP_TAR" -C /hive/miners/custom

echo "[CODED] fixing permissions..."
chmod +x /hive/miners/custom/h-run.sh || true
chmod +x /hive/miners/custom/h-stats.sh || true
chmod +x /hive/miners/custom/h-config.sh || true

chmod +x "$MINER_DIR/start.sh" || true
chmod +x "$MINER_DIR/h-run.sh" || true
chmod +x "$MINER_DIR/h-stats.sh" || true
chmod +x "$MINER_DIR/coded-miner" || true

echo "[CODED] starting miner..."
miner start

echo "[CODED] verifying install..."
ls -lh "$MINER_DIR/coded-miner"

echo "[CODED] DONE"
