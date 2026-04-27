#!/usr/bin/env bash
set -euo pipefail

echo "[CODED] HARD CLEAN START"

INSTALL_URL="https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest.tar.gz"

echo "[CODED] stopping Hive miner..."
miner stop || true
screen -S miner -X quit || true

echo "[CODED] killing old CODED processes..."
pkill -9 -f coded-miner || true
pkill -9 -f "/hive/miners/custom/coded-miner" || true
pkill -9 -f "h-run.sh" || true
pkill -9 -f "start.sh" || true

sleep 2

echo "[CODED] removing old miner files..."
rm -rf /hive/miners/custom/coded-miner
rm -f /hive/miners/custom/h-run.sh
rm -f /hive/miners/custom/h-stats.sh
rm -f /hive/miners/custom/h-config.sh
rm -f /hive/coded-miner-latest.tar.gz
rm -rf /tmp/coded*
rm -rf /var/log/miner/coded-miner

echo "[CODED] downloading latest miner..."
cd /hive
wget --no-cache -O coded-miner-latest.tar.gz "$INSTALL_URL"

echo "[CODED] extracting latest miner..."
mkdir -p /hive/miners/custom
tar -xzf coded-miner-latest.tar.gz -C /hive/miners/custom

echo "[CODED] fixing permissions..."
chmod +x /hive/miners/custom/h-config.sh || true
chmod +x /hive/miners/custom/h-run.sh || true
chmod +x /hive/miners/custom/h-stats.sh || true
chmod +x /hive/miners/custom/coded-miner/* || true

echo "[CODED] verification:"
ls -lah /hive/miners/custom/coded-miner/coded-miner

echo "[CODED] HARD CLEAN DONE"
echo "[CODED] Start again with: miner start"
