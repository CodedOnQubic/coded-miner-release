#!/usr/bin/env bash
# M1091V64_SHARED_RUNSH_V5_AUTOUPDATE_AUTHORITY
# M1091V65A_MACOS_V5_LOCAL_TUNE_RUNNER_BRIDGE_LOADER
#
# One public Linux/macOS lifecycle, one updater. The proven shared runner is
# pinned and patched with V5 compatibility adapters before execution.
# No experiment is started here and no second updater/daemon is introduced.

set -Eeuo pipefail

CORE_COMMIT="d8ddc3f38a105233a6327920373a3ebb2939a55f"
CORE_URL="https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/${CORE_COMMIT}/run.sh"
PATCH_URL="${CODED_RUN_V5_PATCH_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/runtime/run-v5-patch.py}"
TUNE_PATCH_URL="${CODED_RUN_V5_TUNE_PATCH_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/runtime/run-v5-tune-patch.py}"
CONSOLE_URL="${CODED_PUBLIC_CONSOLE_V5_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/runtime/coded-public-console-v5.py}"
CACHE="${TMPDIR:-/tmp}/coded-runsh-v65-${UID:-0}"
CORE="$CACHE/run-core-${CORE_COMMIT}.sh"
PATCHER="$CACHE/run-v5-patch.py"
TUNE_PATCHER="$CACHE/run-v5-tune-patch.py"
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

tmp_tune_patch="$TUNE_PATCHER.tmp.$$"
curl -fsSL --retry 3 --connect-timeout 5 --max-time 20 "$TUNE_PATCH_URL?cb=$(date +%s)" -o "$tmp_tune_patch"
grep -Fq 'M1091V65A_MACOS_V5_LOCAL_TUNE_RUNNER_BRIDGE' "$tmp_tune_patch"
python3 "$tmp_tune_patch" --self-test >/dev/null
mv -f "$tmp_tune_patch" "$TUNE_PATCHER"
chmod 0755 "$TUNE_PATCHER"

tmp_runner="$PATCHED.tmp.$$"
tmp_tuned="$PATCHED.tuned.$$"
python3 "$PATCHER" \
  --input "$CORE" \
  --output "$tmp_runner" \
  --console-url "$CONSOLE_URL" >/dev/null
python3 "$TUNE_PATCHER" \
  --input "$tmp_runner" \
  --output "$tmp_tuned" >/dev/null
mv -f "$tmp_tuned" "$tmp_runner"

bash -n "$tmp_runner"
grep -Fq 'M1091V64A_V5_SOURCE_COMMIT_AUTOUPDATE' "$tmp_runner"
grep -Fq 'M1091V64B_PLATFORM_EXACT_BETA_AUTOUPDATE' "$tmp_runner"
grep -Fq 'M1091V64C_NETWORK_ACCEPTED_PUBLIC_CONSOLE_REFRESH' "$tmp_runner"
grep -Fq 'M1091V64D_PLATFORM_EXACT_INITIAL_BETA' "$tmp_runner"
grep -Fq 'M1091V65A_MACOS_V5_LOCAL_TUNE_RUNNER_BRIDGE' "$tmp_runner"
grep -Fq 'hardware_tune_v5/startup.py' "$tmp_runner"
grep -Fq 'unset CODED_HARDWARE_TUNE_V5_EXECUTED' "$tmp_runner"
grep -Fq 'MINER_EXE="$MINER_BIN"' "$tmp_runner"
grep -Fq '0c5e9e42c6d86c320af62f4125ca85b2446f2b098893fd6521bcf66c22f7f00a' "$tmp_runner"
! grep -Fq 'hardware_tune/probe_adapter.py' "$tmp_runner"
! grep -Fq 'python3 -m hardware_tune.cli' "$tmp_runner"
! grep -Fq '403e24225f5b0512d0cbf49758fed9a01e7334d3cea565ad6c5e82420b713226' "$tmp_runner"

chmod 0755 "$tmp_runner"
mv -f "$tmp_runner" "$PATCHED"

exec bash "$PATCHED" "$@"
