from pathlib import Path
import re

p = Path("run.sh")
s = p.read_text()
orig = s

old = r'''echo "Stopping old CODED public runner processes for worker \$WORKER_SAFE\.\.\."
for pf in "\$PID_DIR/miner\.pid" "\$PID_DIR/analytics\.pid"; do
  if \[ -s "\$pf" \]; then
    kill -9 "\$\(cat "\$pf" 2>/dev/null\)" 2>/dev/null \|\| true
    rm -f "\$pf"
  fi
done

pkill -f "coded-runtime-sidecar\.py\.\*\$\{WORKER_SAFE\}" 2>/dev/null \|\| true
pkill -f "coded-miner\.\*--worker \$\{WORKER_SAFE\}" 2>/dev/null \|\| true
pkill -f "coded-miner-avx2\.\*--worker \$\{WORKER_SAFE\}" 2>/dev/null \|\| true
pkill -f "coded-miner-avx512\.\*--worker \$\{WORKER_SAFE\}" 2>/dev/null \|\| true
pkill -f "coded-miner-scalar\.\*--worker \$\{WORKER_SAFE\}" 2>/dev/null \|\| true
'''

new = '''# M1091V32E_STOP_ALL_PUBLIC_INSTANCES
# Public one-liner policy:
# A new public CODED start replaces all previous public CODED starts on this device.
# Scope is strictly CODED_BASE_DIR / ~/.coded-miner/public, so Hive/builders are not touched.
coded_stop_old_public_instances() {
  local base="${1:-}"
  [ -n "$base" ] || return 0

  echo "Stopping old CODED public runner processes on this device..."

  if [ -d "$base" ]; then
    find "$base" -type f \\( -name "miner.pid" -o -name "analytics.pid" \\) -path "$base/*/pids/*" -print 2>/dev/null | while read -r pf; do
      local pid
      pid="$(cat "$pf" 2>/dev/null || true)"
      if [ -n "$pid" ]; then
        kill "$pid" 2>/dev/null || true
      fi
      rm -f "$pf" 2>/dev/null || true
    done
  fi

  local needle pid cmd
  for needle in coded-miner coded-runtime-sidecar.py coded-public-console.py; do
    pgrep -f "$needle" 2>/dev/null | while read -r pid; do
      cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
      case "$cmd" in
        *"$base"/*"/latest/"*)
          kill "$pid" 2>/dev/null || true
        ;;
      esac
    done
  done

  sleep 1

  for needle in coded-miner coded-runtime-sidecar.py coded-public-console.py; do
    pgrep -f "$needle" 2>/dev/null | while read -r pid; do
      cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
      case "$cmd" in
        *"$base"/*"/latest/"*)
          kill -9 "$pid" 2>/dev/null || true
        ;;
      esac
    done
  done
}

coded_stop_old_public_instances "$BASE"
'''

s2, n = re.subn(old, new, s, count=1)

if n != 1:
    raise SystemExit("ERROR old worker-specific stop block not found")

if "M1091V32E_STOP_ALL_PUBLIC_INSTANCES" not in s2:
    raise SystemExit("ERROR marker missing after patch")

p.write_text(s2)

print("changed=", s2 != orig)
print("OK M1091V32E public runner now stops all previous public instances on this device")
