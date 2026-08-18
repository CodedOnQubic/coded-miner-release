#!/usr/bin/env bash
# M1091V64_SHARED_RUNSH_V5_AUTOUPDATE_AUTHORITY
# M1091V65_SINGLE_PUBLIC_UPDATE_TRANSITION
#
# One public Linux/macOS lifecycle, one updater.  The proven shared runner is
# pinned and patched with the V5 compatibility adapter before execution.
# No experiment is started here and no second updater/daemon is introduced.

set -Eeuo pipefail

CORE_COMMIT="d8ddc3f38a105233a6327920373a3ebb2939a55f"
CORE_URL="https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/${CORE_COMMIT}/run.sh"
PATCH_URL="${CODED_RUN_V5_PATCH_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/runtime/run-v5-patch.py}"
CONSOLE_URL="${CODED_PUBLIC_CONSOLE_V5_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/runtime/coded-public-console-v5.py}"
CACHE="${TMPDIR:-/tmp}/coded-runsh-v64-${UID:-0}"
CORE="$CACHE/run-core-${CORE_COMMIT}.sh"
PATCHER="$CACHE/run-v5-patch.py"
PATCHED="$CACHE/run-v5.sh"

mkdir -p "$CACHE"

if [ ! -s "$CORE" ]; then
  tmp="$CORE.tmp.$$"
  curl -fsSL --retry 3 --connect-timeout 5 --max-time 30 "$CORE_URL" -o "$tmp"
  grep -Fq 'M1091V51P_FINAL_CHANNEL_AWARE_PUBLIC_AUTOUPDATE' "$tmp"
  mv -f "$tmp" "$CORE"
fi

tmp_patch="$PATCHER.tmp.$$"
curl -fsSL --retry 3 --connect-timeout 5 --max-time 20 "$PATCH_URL?cb=$(date +%s)" -o "$tmp_patch"
grep -Fq 'M1091V64_RUNSH_PATCH_V5' "$tmp_patch"
python3 "$tmp_patch" --self-test >/dev/null
mv -f "$tmp_patch" "$PATCHER"
chmod 0755 "$PATCHER"

tmp_runner="$PATCHED.tmp.$$"
python3 "$PATCHER" \
  --input "$CORE" \
  --output "$tmp_runner" \
  --console-url "$CONSOLE_URL" >/dev/null

# M1091V65: collapse every update transition to one visible loader.  The flag
# survives exec-based restarts, suppresses duplicate restart paths for the same
# update, and is cleared only once the fresh productive runner has reached its
# normal autoupdate/startup boundary.
python3 - "$tmp_runner" <<'PYV65'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

def replace_once(anchor: str, replacement: str, label: str) -> None:
    global text
    count = text.count(anchor)
    if count != 1:
        raise SystemExit(f"M1091V65 {label}: expected exactly one anchor, found {count}")
    text = text.replace(anchor, replacement, 1)

replace_once(
'''coded_m1091v54k_public_restart_loader() {
  coded_ui_loader 75 "Applying update"
}''',
'''# M1091V65_SINGLE_UPDATE_LOADER
coded_m1091v54k_public_restart_loader() {
  if [ "${CODED_PUBLIC_UPDATE_UI_SHOWN:-0}" = "1" ]; then
    return 0
  fi
  export CODED_PUBLIC_UPDATE_UI_SHOWN=1
  coded_ui_loader 100 "Applying update"
  coded_ui_loader_finish
}''',
"restart loader",
)

replace_once(
'''  coded_ui_box '$0.01  IS  CODED'
  coded_ui_loader 12 "Updating CODED MINER"
  sleep 1
  coded_ui_loader 45 "Downloading latest CODED MINER"
  sleep 1
  coded_m1091v54k_public_restart_loader
  sleep 1
  coded_ui_loader 100 "Restarting neural network training"
  coded_ui_loader_finish

  coded_m1091v53a_exec_fresh_runsh''',
'''  # M1091V65_SINGLE_UPDATE_FALLBACK
  coded_m1091v54k_public_restart_loader
  coded_m1091v53a_exec_fresh_runsh''',
"legacy multi-loader fallback",
)

replace_once(
'''coded_public_autoupdate_start

coded_ui_warmup "$CODED_PUBLIC_BOOT_SEC"
coded_ui_loader 100 "Neural network training online"
coded_ui_loader_finish''',
'''coded_public_autoupdate_start

if [ "${CODED_PUBLIC_UPDATE_UI_SHOWN:-0}" = "1" ]; then
  # Fresh runner reached productive startup after an update.  Do not render a
  # second warmup/progress bar for the same transition; clear for future updates.
  unset CODED_PUBLIC_UPDATE_UI_SHOWN
else
  coded_ui_warmup "$CODED_PUBLIC_BOOT_SEC"
  coded_ui_loader 100 "Neural network training online"
  coded_ui_loader_finish
fi''',
"post-update startup loader",
)

# The V5 console intentionally has a weekly epoch fallback, but older console
# source treated literal '?' as a valid epoch and therefore displayed E:? after
# an update.  Patch the freshly downloaded canonical console fail-closed at
# refresh time until every packaged console has the corrected source.
console_anchor = '''  chmod 0755 "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$target"
}'''
console_replacement = '''  chmod 0755 "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$target"

  # M1091V65_EPOCH_QUESTION_MARK_REHYDRATION
  python3 - "$target" <<'PYV65EPOCH'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding="utf-8")
old='if value and value.lower() not in ("auto", "none", "null", "unknown"):'
new='if value and value.lower() not in ("auto", "none", "null", "unknown", "?"):'
if s.count(old) != 1:
    raise SystemExit("M1091V65 epoch fallback anchor mismatch")
p.write_text(s.replace(old, new, 1), encoding="utf-8")
PYV65EPOCH
}'''
replace_once(console_anchor, console_replacement, "epoch console refresh")

path.write_text(text, encoding="utf-8")
PYV65

bash -n "$tmp_runner"
grep -Fq 'M1091V64A_V5_SOURCE_COMMIT_AUTOUPDATE' "$tmp_runner"
grep -Fq 'M1091V64B_PLATFORM_EXACT_BETA_AUTOUPDATE' "$tmp_runner"
grep -Fq 'M1091V64C_NETWORK_ACCEPTED_PUBLIC_CONSOLE_REFRESH' "$tmp_runner"
grep -Fq 'M1091V64D_PLATFORM_EXACT_INITIAL_BETA' "$tmp_runner"
grep -Fq 'M1091V65_SINGLE_UPDATE_LOADER' "$tmp_runner"
grep -Fq 'M1091V65_SINGLE_UPDATE_FALLBACK' "$tmp_runner"
grep -Fq 'M1091V65_EPOCH_QUESTION_MARK_REHYDRATION' "$tmp_runner"
grep -Fq '0c5e9e42c6d86c320af62f4125ca85b2446f2b098893fd6521bcf66c22f7f00a' "$tmp_runner"
! grep -Fq '403e24225f5b0512d0cbf49758fed9a01e7334d3cea565ad6c5e82420b713226' "$tmp_runner"

chmod 0755 "$tmp_runner"
mv -f "$tmp_runner" "$PATCHED"

exec bash "$PATCHED" "$@"
