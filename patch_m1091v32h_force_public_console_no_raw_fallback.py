from pathlib import Path

p = Path("run.sh")
s = p.read_text()
orig = s

marker = "M1091V32H_FORCE_PUBLIC_CONSOLE_NO_RAW_FALLBACK"
if marker in s:
    print("already patched")
    raise SystemExit(0)

# 1) Insert helper after install chmod, before pick_exe.
needle = '''cp -R "$ROOT"/. "$INSTALL_DIR"/
chmod +x "$INSTALL_DIR"/* 2>/dev/null || true

pick_exe() {
'''

insert = '''cp -R "$ROOT"/. "$INSTALL_DIR"/
chmod +x "$INSTALL_DIR"/* 2>/dev/null || true

# M1091V32H_FORCE_PUBLIC_CONSOLE_NO_RAW_FALLBACK
# A bad/rebuilt asset must never expose raw dev analytics in the public terminal.
# If the package misses coded-public-console.py, fetch it directly from coded-miner.
coded_ensure_public_console() {
  if [ -f "$INSTALL_DIR/coded-public-console.py" ]; then
    chmod +x "$INSTALL_DIR/coded-public-console.py" 2>/dev/null || true
    return 0
  fi

  local console_url="${CODED_PUBLIC_CONSOLE_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner/m1091v6-clean-hive-autostart/release/hiveos/coded-miner/coded-public-console.py}"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 "$console_url" -o "$INSTALL_DIR/coded-public-console.py" 2>/dev/null || true
  fi

  if [ -f "$INSTALL_DIR/coded-public-console.py" ]; then
    chmod +x "$INSTALL_DIR/coded-public-console.py" 2>/dev/null || true
    return 0
  fi

  echo "ERROR: coded-public-console.py unavailable. Refusing to show raw dev analytics."
  echo "Fix release asset or CODED_PUBLIC_CONSOLE_URL."
  exit 88
}

coded_ensure_public_console

pick_exe() {
'''

if needle not in s:
    raise SystemExit("ERROR install/chmod block not found")

s = s.replace(needle, insert, 1)

# 2) Replace raw fallback block with hard error.
old = '''else
  echo "WARN: coded-public-console.py unavailable, falling back to raw log tail"
  tail -n 40 -f "$RUN_LOG"
fi
'''

new = '''else
  echo "ERROR: coded-public-console.py unavailable. Raw dev analytics will not be shown."
  echo "RUN_LOG is still available internally at: $RUN_LOG"
  exit 88
fi
'''

if old not in s:
    raise SystemExit("ERROR raw fallback block not found")

s = s.replace(old, new, 1)

p.write_text(s)

print("changed=", s != orig)
print("OK M1091V32H public console enforced, raw fallback disabled")
