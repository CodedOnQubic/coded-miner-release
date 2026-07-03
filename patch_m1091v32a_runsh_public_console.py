from pathlib import Path

p = Path("run.sh")
s = p.read_text()
orig = s

# Make nohup sidecar quiet. This avoids "appending output to nohup.out" in public terminal.
s = s.replace(
'''echo "Starting CODED analytics sidecar..."
nohup env \\
''',
'''echo "Starting CODED analytics sidecar..."
nohup env \\
''',
1
)

s = s.replace(
'''  ANALYTICS=YES \\
  python3 "$INSTALL_DIR/coded-runtime-sidecar.py" \\
  >> "$ANALYTICS_LOG" 2>&1 &
''',
'''  ANALYTICS=YES \\
  python3 "$INSTALL_DIR/coded-runtime-sidecar.py" \\
  < /dev/null >> "$ANALYTICS_LOG" 2>&1 &
''',
1
)

old_tail = '''echo "Tail log:"
echo "  tail -f '$RUN_LOG'"
echo ""
tail -n 40 -f "$RUN_LOG"
'''

new_tail = '''echo "Public console:"
echo "  internal raw log: $RUN_LOG"
echo ""

# M1091V32A_PUBLIC_RUNSH_CONSOLE
# Visible terminal uses coded-public-console.py.
# Raw miner/analytics output remains in RUN_LOG for Universal Analytics.
if command -v python3 >/dev/null 2>&1 && [ -f "$INSTALL_DIR/coded-public-console.py" ]; then
  CODED_WORKER_NAME="$WORKER_SAFE" \\
  CODED_WORKER="$WORKER_SAFE" \\
  CODED_RIG_ID="$WORKER_SAFE" \\
  CODED_WALLET="$WALLET" \\
  CODED_THREADS="$THREADS" \\
  CODED_SELECTED_BACKEND="$SELECTED_BACKEND" \\
  CODED_KERNEL_BACKEND="$SELECTED_BACKEND" \\
  CODED_BACKEND="$SELECTED_BACKEND" \\
  CODED_PLATFORM="$PLATFORM" \\
  CODED_PUBLIC_BRAND_EVERY="${CODED_PUBLIC_BRAND_EVERY:-9}" \\
  python3 "$INSTALL_DIR/coded-public-console.py" "$RUN_LOG" "$MINER_PID"
else
  echo "WARN: coded-public-console.py unavailable, falling back to raw log tail"
  tail -n 40 -f "$RUN_LOG"
fi
'''

if old_tail not in s:
    raise SystemExit("ERROR final raw tail block not found in run.sh")

s = s.replace(old_tail, new_tail, 1)

p.write_text(s)
print("changed=", s != orig)
print("OK M1091V32A run.sh uses public console instead of raw log tail")
