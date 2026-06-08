#!/usr/bin/env bash
set -euo pipefail

# M10.99Z273Y5_BIG_COCKPIT_AND_NODE_PATH
# launchd has a minimal PATH; expose Homebrew/Node/CMake for build agent.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# M10.99Z273Y_MAC_ARM_FLEET_CONSOLE_LAUNCHAGENT

WORKER="${WORKER:-${CODED_WORKER_NAME:-my-mac}}"
DEVICE_ID="${DEVICE_ID:-${CODED_DEVICE_ID:-macos-arm64:${WORKER}}}"
WALLET="${WALLET:-${CODED_WALLET:-}}"
BUILDER="${BUILDER:-${CODED_ENABLE_BUILD_AGENT:-0}}"
AUTOUPDATE="${AUTOUPDATE:-YES}"
BASE_DIR="${CODED_MAC_BASE_DIR:-/tmp/coded-miner-macos-arm64}"

# M10.99Z273Y6_FIXED_COCKPIT_LAUNCH_AND_PATH
CODED_LAUNCH_PATH="${CODED_LAUNCH_PATH:-/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin}"
export PATH="$CODED_LAUNCH_PATH:$PATH"
LABEL_SAFE="$(echo "$WORKER" | tr -cd '[:alnum:]_.-' | sed 's/__*/_/g')"
# M10.99Z273Y4_SAFE_WORKER_ALIAS
# Console LaunchAgent block uses SAFE_WORKER; keep it synced with LABEL_SAFE.
SAFE_WORKER="${SAFE_WORKER:-$LABEL_SAFE}"
PLIST="$HOME/Library/LaunchAgents/com.coded.macarm.${LABEL_SAFE}.plist"
RUNNER="$HOME/.coded/mac-arm/${WORKER}/run-supervisor.sh"
CONSOLE="$HOME/.coded/mac-arm/${WORKER}/console.sh"

# M10.99Z273Y3_INSTALL_DIR_RUNTIME_SCRIPT_COPY
# Make installer self-contained when running from local coded-miner repo.
INSTALL_DIR="${INSTALL_DIR:-$(dirname "$CONSOLE")}"
BASE_DIR="${CODED_MAC_BASE_DIR:-/tmp/coded-miner-macos-arm64}"

mkdir -p "$BASE_DIR/scripts/macos" "$BASE_DIR/scripts" "$INSTALL_DIR"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

copy_runtime_script_z273y3() {
  local src="$1"
  local dst="$2"

  if [ -f "$REPO_ROOT/$src" ]; then
    cp "$REPO_ROOT/$src" "$dst"
    chmod +x "$dst" 2>/dev/null || true
    echo "[M10.99Z273Y3] copied $src -> $dst"
    return 0
  fi

  echo "[M10.99Z273Y3] WARN missing local script: $REPO_ROOT/$src"
  return 0
}

copy_runtime_script_z273y3 "scripts/macos/coded_mac_arm_supervisor_z273g.sh" "$BASE_DIR/scripts/macos/coded_mac_arm_supervisor_z273g.sh"
copy_runtime_script_z273y3 "scripts/macos/coded_mac_arm_public_console_z273n.sh" "$BASE_DIR/scripts/macos/coded_mac_arm_public_console_z273n.sh"
copy_runtime_script_z273y3 "scripts/external_arm_build_agent_z265b.sh" "$BASE_DIR/scripts/external_arm_build_agent_z265b.sh"
copy_runtime_script_z273y3 "scripts/coded_mac_arm_log_uploader.py" "$BASE_DIR/coded_mac_arm_log_uploader.py"


if [ -z "$WALLET" ]; then
  echo "ERROR: missing WALLET"
  echo "Usage:"
  echo 'WALLET=YOUR_WALLET WORKER=my-mac BUILDER=0 bash scripts/macos/install_coded_mac_arm_fleet_console_z273y.sh'
  exit 1
fi

mkdir -p "$(dirname "$RUNNER")" "$HOME/Library/LaunchAgents"

cat > "$RUNNER" <<EOF
#!/usr/bin/env bash

# M10.99Z273AB2_RUNNER_LOG_ENV_ROBUST
export CODED_MINER_LOG="/tmp/coded-miner-${WORKER}.log"
export CODED_MAC_LOG="/tmp/coded-miner-${WORKER}.log"
export CODED_UPLOADER_LOG="/tmp/coded-mac-arm-uploader-${WORKER}.log"
export CODED_SELF_UPDATE_ENABLED="${AUTOUPDATE:-YES}"
export CODED_SELF_UPDATE_SUPERVISOR="${AUTOUPDATE:-YES}"
export CODED_BUILDER="${BUILDER:-0}"
export CODED_ENABLE_BUILD_AGENT="${BUILDER:-0}"
set -euo pipefail

BASE_DIR="$BASE_DIR"
WORKER="$WORKER"
DEVICE_ID="$DEVICE_ID"
WALLET="$WALLET"
BUILDER="$BUILDER"
AUTOUPDATE="$AUTOUPDATE"

SUP="\$BASE_DIR/scripts/macos/coded_mac_arm_supervisor_z273g.sh"

if [ ! -x "\$SUP" ]; then
  echo "[CODED] supervisor missing at \$SUP"
  echo "[CODED] run public one-liner once to install latest runtime scripts."
  exit 1
fi

export CODED_WORKER_NAME="\$WORKER"
export CODED_DEVICE_ID="\$DEVICE_ID"
export CODED_WALLET="\$WALLET"
export CODED_SELF_UPDATE_CHECK_SEC="\${CODED_SELF_UPDATE_CHECK_SEC:-60}"
export CODED_SELF_UPDATE_ENABLED="\$AUTOUPDATE"
export CODED_POOL_API="\${CODED_POOL_API:-http://pool.codedonqubic.com:4000/fleet/devices/heartbeat}"
export CODED_POOL_API_ROOT="\${CODED_POOL_API_ROOT:-http://pool.codedonqubic.com:4000}"
export CODED_ENABLE_BUILD_AGENT="\$BUILDER"
export CODED_DISABLE_BUILD_AGENT="\$([ "\$BUILDER" = "1" ] && echo 0 || echo 1)"

exec "\$SUP"
EOF

chmod +x "$RUNNER"

cat > "$CONSOLE" <<EOF
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$BASE_DIR"
export CODED_WORKER_NAME="$WORKER"
export CODED_DEVICE_ID="$DEVICE_ID"
export CODED_WALLET="$WALLET"
export CODED_SELF_UPDATE_ENABLED="$AUTOUPDATE"
export CODED_ENABLE_BUILD_AGENT="$BUILDER"

exec "\$BASE_DIR/scripts/macos/coded_mac_arm_public_console_z273n.sh"
EOF

chmod +x "$CONSOLE"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.coded.macarm.${LABEL_SAFE}</string>

    <key>EnvironmentVariables</key>
    <dict>
      <key>PATH</key>
      <string>$CODED_LAUNCH_PATH</string>
    </dict>
    <key>ProgramArguments</key>
    <array>
      <string>$RUNNER</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>WorkingDirectory</key>
    <string>$HOME</string>

    <key>StandardOutPath</key>
    <string>/tmp/coded-mac-arm-launchagent-${WORKER}.out.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/coded-mac-arm-launchagent-${WORKER}.err.log</string>
  </dict>
</plist>
EOF

launchctl unload "$PLIST" >/dev/null 2>&1 || true
launchctl load "$PLIST"

echo
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║              CODED MAC ARM FLEET CONSOLE INSTALLED               ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo
echo "worker       $WORKER"
echo "device       $DEVICE_ID"
echo "builder      $BUILDER"
echo "autoupdate   $AUTOUPDATE"
echo "plist        $PLIST"
echo "runner       $RUNNER"
echo "console      $CONSOLE"
echo

# M10.99Z273Y2_TERMINAL_AUTO_OPEN
OPEN_CONSOLE="$INSTALL_DIR/open-console.sh"
cat > "$OPEN_CONSOLE" <<SH
#!/usr/bin/env bash
# M10.99Z273Y8_APPLESCRIPT_SAFE_COCKPIT_OPEN
export PATH="$CODED_LAUNCH_PATH:\$PATH"

CONSOLE_PATH="$CONSOLE"

osascript - "\$CONSOLE_PATH" <<'OSA'
on run argv
  set consolePath to item 1 of argv
  set shellCmd to "clear; exec " & quoted form of consolePath

  tell application "Terminal"
    activate
    do script shellCmd
    delay 0.7
    try
      set bounds of front window to {25, 25, 1450, 1020}
    end try
  end tell
end run
OSA
SH
chmod +x "$OPEN_CONSOLE"

PLIST_CONSOLE="$HOME/Library/LaunchAgents/com.coded.macarm.${SAFE_WORKER}.console.plist"
cat > "$PLIST_CONSOLE" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.coded.macarm.${SAFE_WORKER}.console</string>
    <key>ProgramArguments</key>
    <array>
      <string>$OPEN_CONSOLE</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$INSTALL_DIR/console-launch.out.log</string>
    <key>StandardErrorPath</key>
    <string>$INSTALL_DIR/console-launch.err.log</string>
  </dict>
</plist>
PLIST

launchctl unload "$PLIST_CONSOLE" >/dev/null 2>&1 || true
launchctl load "$PLIST_CONSOLE" >/dev/null 2>&1 || true
"$OPEN_CONSOLE" >/dev/null 2>&1 || true


echo "Open visible cockpit:"
echo "  $CONSOLE"
echo
echo "Stop service:"
echo "  launchctl unload $PLIST"
