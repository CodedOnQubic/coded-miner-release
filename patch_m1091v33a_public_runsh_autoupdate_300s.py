from pathlib import Path

p = Path("run.sh")
s = p.read_text()
orig = s

marker = "M1091V33A_PUBLIC_RUNSH_AUTOUPDATE_300S"
if marker in s:
    print("already patched")
    raise SystemExit(0)

needle = '''TMP_DIR="$STATE_DIR/download.$$"
TAR_FILE="$STATE_DIR/coded-miner.tar.gz"
'''

replace = '''TMP_DIR="$STATE_DIR/download.$$"
TAR_FILE="$STATE_DIR/coded-miner.tar.gz"

# M1091V33A_PUBLIC_RUNSH_AUTOUPDATE_300S
# Central public auto-update interval. Override with CODED_PUBLIC_UPDATE_SEC=...
CODED_PUBLIC_UPDATE_SEC="${CODED_PUBLIC_UPDATE_SEC:-300}"
CODED_PUBLIC_RUNSH_URL="${CODED_PUBLIC_RUNSH_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/run.sh}"
'''

if needle not in s:
    raise SystemExit("ERROR TMP_DIR/TAR_FILE block not found")

s = s.replace(needle, replace, 1)

needle = '''coded_ensure_public_console

pick_exe() {
'''

insert = '''coded_ensure_public_console

coded_manifest_commit() {
  local dir="$1"
  local mf=""

  for mf in "$dir/release_manifest.json" "$dir/manifest.json" "$dir/coded-miner/release_manifest.json" "$dir/coded-miner/manifest.json"; do
    if [ -s "$mf" ]; then
      sed -nE 's/.*"commit"[[:space:]]*:[[:space:]]*"([^"]+)".*/\\1/p' "$mf" | head -1
      return 0
    fi
  done

  find "$dir" -maxdepth 3 -type f \\( -name "release_manifest.json" -o -name "manifest.json" \\) 2>/dev/null | while read -r mf; do
    sed -nE 's/.*"commit"[[:space:]]*:[[:space:]]*"([^"]+)".*/\\1/p' "$mf" | head -1
    break
  done
}

coded_public_autoupdate_start() {
  case "${CODED_DISABLE_PUBLIC_AUTOUPDATE:-0}" in
    1|YES|yes|true|TRUE)
      return 0
    ;;
  esac

  command -v curl >/dev/null 2>&1 || return 0
  command -v tar >/dev/null 2>&1 || return 0

  (
    log_file="$LOG_DIR/public-autoupdate.log"

    while true; do
      sleep "$CODED_PUBLIC_UPDATE_SEC"

      cur_commit="$(coded_manifest_commit "$INSTALL_DIR" | head -1)"
      work="$STATE_DIR/update-check.$$.$RANDOM"
      tar_file="$work/latest.tar.gz"
      extract="$work/extract"

      rm -rf "$work"
      mkdir -p "$extract" 2>/dev/null || true

      download_ok=0
      for u in ${ASSET_URLS:-$ASSET_URL}; do
        if curl -fsSL --retry 2 "$u" -o "$tar_file" 2>>"$log_file"; then
          download_ok=1
          break
        fi
      done

      if [ "$download_ok" != "1" ]; then
        echo "[M1091V33A_PUBLIC_RUNSH_AUTOUPDATE_300S] download_failed keep_current at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log_file"
        rm -rf "$work"
        continue
      fi

      if ! tar -xzf "$tar_file" -C "$extract" >> "$log_file" 2>&1; then
        echo "[M1091V33A_PUBLIC_RUNSH_AUTOUPDATE_300S] extract_failed keep_current at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log_file"
        rm -rf "$work"
        continue
      fi

      root="$extract"
      [ -d "$extract/coded-miner" ] && root="$extract/coded-miner"

      new_commit="$(coded_manifest_commit "$root" | head -1)"

      if [ -z "$new_commit" ]; then
        echo "[M1091V33A_PUBLIC_RUNSH_AUTOUPDATE_300S] new_commit_missing keep_current cur=$cur_commit at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log_file"
        rm -rf "$work"
        continue
      fi

      if [ -n "$cur_commit" ] && [ "$new_commit" = "$cur_commit" ]; then
        echo "[M1091V33A_PUBLIC_RUNSH_AUTOUPDATE_300S] already_latest commit=$new_commit at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log_file"
        rm -rf "$work"
        continue
      fi

      echo "$new_commit" > "$PID_DIR/update.request"
      echo "[M1091V33A_PUBLIC_RUNSH_AUTOUPDATE_300S] update_available old=${cur_commit:-missing} new=$new_commit restarting at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log_file"

      kill "$MINER_PID" 2>/dev/null || true
      kill "$ANALYTICS_PID" 2>/dev/null || true

      rm -rf "$work"
      exit 0
    done
  ) &

  UPDATE_PID="$!"
  echo "$UPDATE_PID" > "$PID_DIR/autoupdate.pid" 2>/dev/null || true
}

pick_exe() {
'''

if needle not in s:
    raise SystemExit("ERROR coded_ensure_public_console / pick_exe block not found")

s = s.replace(needle, insert, 1)

needle = '''ANALYTICS_PID=$!
echo "$ANALYTICS_PID" > "$PID_DIR/analytics.pid"
'''

replace = '''ANALYTICS_PID=$!
echo "$ANALYTICS_PID" > "$PID_DIR/analytics.pid"

coded_public_autoupdate_start
'''

if needle not in s:
    raise SystemExit("ERROR analytics pid block not found")

s = s.replace(needle, replace, 1)

old = '''if command -v python3 >/dev/null 2>&1 && [ -f "$INSTALL_DIR/coded-public-console.py" ]; then
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
  echo "ERROR: coded-public-console.py unavailable. Raw dev analytics will not be shown."
  echo "RUN_LOG is still available internally at: $RUN_LOG"
  exit 88
fi
'''

new = '''CONSOLE_RC=0

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
  CODED_PUBLIC_LINE_SEC="${CODED_PUBLIC_LINE_SEC:-1}" \\
  python3 "$INSTALL_DIR/coded-public-console.py" "$RUN_LOG" "$MINER_PID" || CONSOLE_RC="$?"
else
  echo "ERROR: coded-public-console.py unavailable. Raw dev analytics will not be shown."
  echo "RUN_LOG is still available internally at: $RUN_LOG"
  exit 88
fi

if [ -n "${UPDATE_PID:-}" ]; then
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

if old not in s:
    raise SystemExit("ERROR public console final block not found")

s = s.replace(old, new, 1)

p.write_text(s)

print("changed=", s != orig)
print("OK M1091V33A public run.sh auto-update every CODED_PUBLIC_UPDATE_SEC")
