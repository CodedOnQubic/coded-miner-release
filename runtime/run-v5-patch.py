#!/usr/bin/env python3
"""Patch the proven shared public runner with Anthill V5 compatibility.

The patch does not add another updater.  It repairs the existing Linux/macOS
run.sh lifecycle before execution.
"""
from __future__ import annotations

import argparse
from pathlib import Path

MARKER = "M1091V64_RUNSH_PATCH_V5"
LEGACY_TASK_SHA = "403e24225f5b0512d0cbf49758fed9a01e7334d3cea565ad6c5e82420b713226"
SOLUTION_AUTHORITY_V3_TASK_SHA = "0c5e9e42c6d86c320af62f4125ca85b2446f2b098893fd6521bcf66c22f7f00a"


def linux_v1306(text: str) -> str:
    """Extend only the pinned lifecycle; no second supervisor/updater."""
    for cpu in ('avx2', 'avx512'):
        text = replace_once(text, f'-{cpu}) BACKEND="{cpu}" ;;',
                            f'-{cpu}) CODED_PUBLIC_CPU_REQUEST={cpu}; BACKEND={cpu} ;;', 'CPU selector')
    text = replace_once(text, 'while [ $# -gt 0 ]; do\n  case "$1" in\n    -avx2)',
        '''# CODED_LINUX_V1306_PUBLIC_ARGUMENTS
CODED_PUBLIC_GPU_REQUEST=0
CODED_PUBLIC_GPU_ONLY_REQUEST=0
CODED_PUBLIC_CPU_REQUEST=auto
CODED_PUBLIC_THREADS_EXPLICIT=0
export PYTHONDONTWRITEBYTECODE=1
[ -z "${CODED_THREADS:-}" ] && [ "${THREADS:-0}" = 0 ] || CODED_PUBLIC_THREADS_EXPLICIT=1
while [ $# -gt 0 ]; do
  case "$1" in
    -gpu|--gpu) CODED_PUBLIC_GPU_REQUEST=1 ;;
    -gpu_only|--gpu-only) CODED_PUBLIC_GPU_ONLY_REQUEST=1 ;;
    --threads|-t)
      shift; [ $# -gt 0 ] || exit 64
      THREADS="$1"; CODED_PUBLIC_THREADS_EXPLICIT=1 ;;
    -avx2)''', 'Linux backend arguments')
    text = replace_once(text, '\nWALLET="${WALLET:-${QUBIC_WALLET:-${CODED_WALLET:-}}}"', '''
# CPU selection and GPU enablement are independent, order-independent inputs.
case "$BACKEND" in avx2|avx512) CODED_PUBLIC_CPU_REQUEST="$BACKEND" ;; esac
if [ "$CODED_PUBLIC_GPU_ONLY_REQUEST" = 1 ]; then
  [ "$CODED_PUBLIC_GPU_REQUEST" = 0 ] && [ "$CODED_PUBLIC_CPU_REQUEST" = auto ] || {
    echo 'ERROR: conflicting GPU-only and CPU/Hybrid arguments' >&2; exit 64;
  }
  BACKEND=cuda
elif [ "$CODED_PUBLIC_GPU_REQUEST" = 1 ]; then BACKEND=hybrid
fi
export CODED_PUBLIC_CPU_REQUEST CODED_PUBLIC_THREADS_EXPLICIT
WALLET="${WALLET:-${QUBIC_WALLET:-${CODED_WALLET:-}}}"''', 'Linux resolved request')
    # Numeric shorthand/equal-form thread options also count as explicit.
    for anchor in ('-[0-9]*) THREADS="${1#-}" ;;', '--threads=*) THREADS="${1#--threads=}" ;;', '-t=*) THREADS="${1#-t=}" ;;'):
        text = replace_once(text, anchor, anchor[:-3] + '; CODED_PUBLIC_THREADS_EXPLICIT=1 ;;', 'explicit Linux threads')
    text = replace_once(text, 'pick_exe() {\n', '''pick_exe() {
  if [ "$PLATFORM" = linux-amd64 ] && [ -f "$INSTALL_DIR/linux_v1306_runtime.py" ]; then
    python3 -B "$INSTALL_DIR/linux_v1306_runtime.py" --root "$INSTALL_DIR" --backend "$BACKEND" --threads "$THREADS" --select-only
    return $?
  fi
  case "$BACKEND" in cuda|hybrid)
    echo 'ERROR: requested GPU mode has no qualified current-profile runtime' >&2; return 1 ;;
  esac
''', 'Linux native executable selection')
    text = replace_once(text, '# M1091V55F: install terminal traps before first runtime child starts.', '''# CODED_LINUX_V1306_NATIVE_ACTIVATION
if [ "$PLATFORM" = linux-amd64 ] && [ -f "$INSTALL_DIR/linux_v1306_runtime.py" ]; then
  CODED_ANT_V3_STATE_DIR="$STATE_DIR/ant-v3"
  [ ! -L "$CODED_ANT_V3_STATE_DIR" ] || exit 66
  mkdir -p "$CODED_ANT_V3_STATE_DIR"
  exec 207>"$CODED_ANT_V3_STATE_DIR/.runtime-mode.lock"
  flock -n 207 || { echo 'ERROR: native state owner already running' >&2; exit 75; }
  export WALLET WORKER
  activation="$(mktemp "$STATE_DIR/.native-activation.XXXXXX")"
  python3 -B "$INSTALL_DIR/linux_v1306_runtime.py" --root "$INSTALL_DIR" --backend "$BACKEND" --threads "$THREADS" \\
    --state "$CODED_ANT_V3_STATE_DIR" --lease-fd 207 > "$activation" || exit 66
  source "$activation"
  rm -f "$activation"
  # A parent-owned update can inherit old build labels. Replace every source
  # input with the verified installed manifest; never mix two release SHAs.
  export CODED_MINER_COMMIT="$CODED_SOURCE_COMMIT" GIT_COMMIT="$CODED_SOURCE_COMMIT"
  export CODED_EXPECTED_RELEASE_COMMIT="$CODED_SOURCE_COMMIT"
  CODED_RELEASE_VERSION="$(python3 -B - "$INSTALL_DIR/release_manifest.json" "$CODED_SOURCE_COMMIT" <<'PYV1306VERSION'
import json,re,sys
version=json.load(open(sys.argv[1]))['version']
assert re.fullmatch(r'[A-Za-z0-9_.+-]+',version) and sys.argv[2] in version
print(version)
PYV1306VERSION
)" || exit 66
  export CODED_RELEASE_VERSION CODED_MINER_VERSION="$CODED_RELEASE_VERSION"
  export CODED_BPP9000_WORKER_INDEX_BASE=0 CODED_CUDA_WORKERS=8 CODED_CUDA_V1306_THREADS=64
  export CODED_ROUTER_PROFILE=ant_v3_live CODED_ARCHITECTURE=x86_64 CODED_CPU_ARCH=x86_64
  export CODED_BUILD_TARGET="linux-amd64-$SELECTED_BACKEND"
  unset CODED_THRESHOLD THRESHOLD
  # Legacy env blocks below require a value, but native scoring reads only
  # Qatum's job threshold. Do not advertise a fabricated static threshold.
  THRESHOLD=dynamic_from_qatum_v3
  export CODED_ANALYTICS2_REQUIRE_PID_ELF=1 CODED_ANALYTICS2_REQUIRE_NATIVE_FRAME=YES CODED_MINER_BINARY="$MINER_EXE"
  export CODED_ANALYTICS2_REQUIRE_PROCESS_OWNER=YES CODED_RUNTIME_SIDECAR_PARENT_PID="$$"
fi

# M1091V55F: install terminal traps before first runtime child starts.''', 'Linux V3 activation')
    text = replace_once(text, 'MINER_PID=$!\necho "$MINER_PID" > "$PID_DIR/miner.pid"',
        'MINER_PID=$!\nexport CODED_MINER_PID="$MINER_PID" CODED_RUNTIME_PROCESS_ID="$MINER_PID"\necho "$MINER_PID" > "$PID_DIR/miner.pid"', 'native PID binding')
    stop_start = text.index('coded_m1091v55f_stop_child_single() {')
    stop_end = text.index('# M1091V55F_R3_DESCENDANT_GROUP_CLEANUP_BEGIN', stop_start)
    stop = text[stop_start:stop_end]
    patched_stop = replace_once(stop, '    if [ "$tick" -ge 20 ]; then', '''    # A native mode change requires a drained durable checkpoint. This is
    # bounded; a killed/ambiguous process cannot fabricate a handoff receipt.
    local limit=20
    if [ "${CODED_NATIVE_MODE_HANDOFF:-0}" = 1 ] && [ "$pid" = "${MINER_PID:-}" ]; then limit=500; fi
    if [ "$tick" -ge "$limit" ]; then''', 'native bounded drain')
    text = text[:stop_start] + patched_stop + text[stop_end:]
    for start, end in (('coded_m1091v51p_kill_current_public_children() {', 'coded_m1091v55b_quiet_stop_public_children() {'),
                       ('coded_m1091v55b_quiet_stop_public_children() {', '# M1091V55F_PUBLIC_SIGNAL_TREE_CLEANUP_BEGIN')):
        begin = text.index(start)
        finish = text.index(end, begin)
        old = text[begin:finish]
        # Preserve the legacy implementation for non-current packages.
        text = text[:begin] + old.replace('\n', '''
  if [ "${CODED_NATIVE_MODE_HANDOFF:-0}" = 1 ]; then
    coded_m1091v55f_cleanup_children update
    return 0
  fi
''', 1) + text[finish:]
    return text


def replace_once(text: str, anchor: str, replacement: str, label: str) -> str:
    if text.count(anchor) != 1:
        raise RuntimeError(f"{label}: expected exactly one anchor, found {text.count(anchor)}")
    return text.replace(anchor, replacement, 1)


def transform(text: str, console_url: str) -> str:
    for token in (
        "M1091V51P_FINAL_CHANNEL_AWARE_PUBLIC_AUTOUPDATE",
        "coded_public_autoupdate_start()",
        "coded_m1091v53a_exec_fresh_runsh()",
        "coded_ensure_public_console",
        LEGACY_TASK_SHA,
    ):
        if token not in text:
            raise RuntimeError("pinned runner contract missing: " + token)

    # V5 Solution Authority V3 task.  New packages must carry this exact task;
    # the old public fallback task will fail closed if a V5 package omits it.
    text = text.replace(LEGACY_TASK_SHA, SOLUTION_AUTHORITY_V3_TASK_SHA)

    console_anchor = "coded_ensure_public_console\n\ncoded_manifest_commit() {"
    console_patch = r'''coded_ensure_public_console

# M1091V64C_NETWORK_ACCEPTED_PUBLIC_CONSOLE_REFRESH
coded_m1091v64c_refresh_public_console() {
  local target tmp url
  target="$INSTALL_DIR/coded-public-console.py"
  # Current packages contain the native-frame console tied to their source.
  # Never overwrite that file with the legacy V5 console from raw main.
  if [ -f "$INSTALL_DIR/linux_v1306_runtime.py" ]; then
    [ -s "$target" ] || exit 88
    return 0
  fi
  tmp="${target}.v64.$$"
  url="__CONSOLE_URL__"
  rm -f "$tmp" 2>/dev/null || true

  if ! curl -fsSL --retry 3 --connect-timeout 5 --max-time 20 "$url?cb=$(date +%s)" -o "$tmp"; then
    echo "ERROR: canonical V5 public console unavailable"
    rm -f "$tmp" 2>/dev/null || true
    exit 88
  fi

  grep -Fq 'M1091V64A_NETWORK_ACCEPTED_PUBLIC_CONSOLE' "$tmp" || {
    echo "ERROR: canonical V5 public console marker missing"
    rm -f "$tmp" 2>/dev/null || true
    exit 88
  }

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$tmp" <<'PYCHECK' || exit 88
import ast,sys
source=open(sys.argv[1], encoding="utf-8").read()
ast.parse(source, filename=sys.argv[1])
for forbidden in (
    'or frame.get("total_pass")',
    'or frame.get("real300")',
    'or frame.get("real321")',
    'or frame.get("accepted")',
):
    if forbidden in source:
        raise SystemExit("legacy solution fallback detected: "+forbidden)
PYCHECK
  fi

  chmod 0755 "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$target"
}

coded_m1091v64c_refresh_public_console

coded_manifest_commit() {'''.replace("__CONSOLE_URL__", console_url)
    text = replace_once(text, console_anchor, console_patch, "console refresh")

    manifest_anchor = "coded_m1091v51p_platform_asset_name() {"
    manifest_override = r'''# M1091V64A_V5_SOURCE_COMMIT_AUTOUPDATE
coded_manifest_commit() {
  local dir="$1"
  local mf=""
  local value=""

  for mf in \
    "$dir/release_manifest.json" \
    "$dir/manifest.json" \
    "$dir/coded-miner/release_manifest.json" \
    "$dir/coded-miner/manifest.json"
  do
    [ -s "$mf" ] || continue

    if command -v python3 >/dev/null 2>&1; then
      value="$(python3 - "$mf" <<'PYCOMMIT' 2>/dev/null || true
import json,re,sys
try:
    data=json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    raise SystemExit(0)
for key in ("source_commit","release_commit","commit","git_commit","miner_commit"):
    value=str(data.get(key) or "").strip().lower()
    if re.fullmatch(r"[0-9a-f]{7,40}", value):
        print(value)
        break
PYCOMMIT
)"
    else
      value="$(grep -Eo '"(source_commit|release_commit|commit|git_commit|miner_commit)"[[:space:]]*:[[:space:]]*"[0-9a-fA-F]{7,40}"' "$mf" 2>/dev/null | head -1 | sed -E 's/.*"([0-9a-fA-F]{7,40})".*/\1/' | tr '[:upper:]' '[:lower:]' || true)"
    fi

    if printf '%s' "$value" | grep -Eq '^[0-9a-f]{7,40}$'; then
      printf '%s\n' "$value"
      return 0
    fi
  done

  return 0
}

'''
    text = replace_once(text, manifest_anchor, manifest_override + manifest_anchor, "manifest identity")

    effective_anchor = "coded_m1091v51p_kill_current_public_children() {"
    effective_override = r'''# M1091V64B_PLATFORM_EXACT_BETA_AUTOUPDATE
coded_m1091v51p_effective_release_line() {
  local pool status_json wants_beta
  pool="${CODED_POOL_API_URL:-${POOL_API_URL:-http://178.104.150.57:4000}}"
  wants_beta=0
  case "${CODED_BETA_REQUESTED:-${CODED_BETA:-${BETA:-}}}" in
    1|yes|YES|true|TRUE|beta|BETA) wants_beta=1 ;;
  esac

  status_json="$(curl -fsSL --connect-timeout 5 --max-time 15 "${pool%/}/admin/release/channel-status?cb=$(date +%s)" 2>/dev/null || true)"
  if [ -z "$status_json" ]; then
    printf '%s|%s|%s|%s|%s\n' \
      "${CODED_RELEASE_CHANNEL:-latest}" \
      "${CODED_RELEASE_VERSION:-${RELEASE_VERSION:-}}" \
      "${CODED_RELEASE_COMMIT:-${GIT_COMMIT:-}}" \
      "${CODED_RELEASE_ASSET_NAME:-}" \
      "${CODED_RELEASE_DOWNLOAD_URL:-${ASSET_URL:-}}"
    return 0
  fi

  STATUS_JSON="$status_json" python3 - "$wants_beta" "${PLATFORM:-}" <<'PYSEL'
import json,os,re,sys
want_beta=sys.argv[1]=="1"
platform=sys.argv[2] or ""
repo="https://github.com/CodedOnQubic/coded-miner-release/releases"
try: data=json.loads(os.environ.get("STATUS_JSON") or "{}")
except Exception: data={}
latest=data.get("public_latest") or {}
beta=data.get("beta") or {}
disabled=data.get("beta_disabled") or {}

def asset_name(channel):
    if platform=="macos-arm64":
        return "coded-miner-macos-arm64-beta-latest.tar.gz" if channel=="beta" else "coded-miner-macos-arm64-latest.tar.gz"
    if platform.startswith("windows") or platform.startswith("win"):
        return "coded-miner-windows-amd64-beta-latest.tar.gz" if channel=="beta" else "coded-miner-windows-amd64-latest.tar.gz"
    return "coded-miner-beta-latest.tar.gz" if channel=="beta" else "coded-miner-latest.tar.gz"

def platform_asset_ok(obj):
    assets=obj.get("assets") if isinstance(obj.get("assets"),dict) else {}
    if platform=="macos-arm64": keys=("macos_arm64","macos-arm64","macos","mac")
    elif platform.startswith(("windows","win")): keys=("windows","windows_amd64")
    else: keys=("linux","hive")
    for key in keys:
        item=assets.get(key)
        if isinstance(item,dict):
            if item.get("ok") is False or str(item.get("status") or "").lower() in {"failed","error","missing"}: return False
        elif item is False:
            return False
    return True

commit=str(beta.get("commit") or beta.get("source_commit") or "").strip().lower()
version=str(beta.get("version") or "").strip()
status=str(beta.get("status") or "").strip().lower()
stage=str(beta.get("stage") or "").strip().lower()
disabled_commit=str(disabled.get("commit") or "").strip().lower()
is_disabled=bool(disabled.get("disabled")) and (not disabled_commit or disabled_commit==commit)
ready_words={"completed","complete","ok","ready","published","active"}
ready=(want_beta and version and re.fullmatch(r"[0-9a-f]{40}",commit) and not is_disabled
       and (not status or status in ready_words) and (not stage or stage in ready_words)
       and platform_asset_ok(beta))
if ready:
    asset=asset_name("beta")
    print("|".join(("beta",version,commit,asset,f"{repo}/download/{version}/{asset}")))
    raise SystemExit(0)
version=str(latest.get("version") or "")
commit=str(latest.get("commit") or latest.get("source_commit") or "")
asset=asset_name("latest")
url=f"{repo}/download/{version}/{asset}" if version else f"{repo}/latest/download/{asset}"
print("|".join(("latest",version,commit,asset,url)))
PYSEL
}

'''
    text = replace_once(text, effective_anchor, effective_override + effective_anchor, "effective Beta selection")

    try_anchor = "# M1091V50I2_RUN_SH_STATUS_WRAPPER"
    try_override = r'''# M1091V64D_PLATFORM_EXACT_INITIAL_BETA
coded_m1091v50h_try_beta() {
  [ "${CODED_BETA_BOOTSTRAP_ACTIVE:-}" = "1" ] && return 1
  coded_m1091v50h_beta_requested "$@" || return 1

  local pool channel_url status_json beta_line beta_version beta_commit beta_asset_name beta_url
  pool="${CODED_POOL_API_URL:-${POOL_API_URL:-http://178.104.150.57:4000}}"
  channel_url="${CODED_RELEASE_CHANNEL_STATUS_URL:-${pool%/}/admin/release/channel-status}"
  status_json="$(curl -fsSL --connect-timeout 5 --max-time 15 "${channel_url}?cb=$(date +%s)" 2>/dev/null || true)"
  [ -n "$status_json" ] || return 1

  beta_line="$(STATUS_JSON="$status_json" python3 - "$(uname -s 2>/dev/null)" "$(uname -m 2>/dev/null)" <<'PYBOOT'
import json,os,re,sys
system=(sys.argv[1] or "").lower(); arch=(sys.argv[2] or "").lower()
platform="macos-arm64" if system=="darwin" and arch in {"arm64","aarch64"} else "linux-amd64"
try: data=json.loads(os.environ.get("STATUS_JSON") or "{}")
except Exception: data={}
beta=data.get("beta") or {}; disabled=data.get("beta_disabled") or {}
commit=str(beta.get("commit") or beta.get("source_commit") or "").strip().lower()
version=str(beta.get("version") or "").strip()
status=str(beta.get("status") or "").strip().lower(); stage=str(beta.get("stage") or "").strip().lower()
disabled_commit=str(disabled.get("commit") or "").strip().lower()
is_disabled=bool(disabled.get("disabled")) and (not disabled_commit or disabled_commit==commit)
assets=beta.get("assets") if isinstance(beta.get("assets"),dict) else {}
keys=("macos_arm64","macos-arm64","macos","mac") if platform=="macos-arm64" else ("linux","hive")
asset_ok=True
for key in keys:
    item=assets.get(key)
    if isinstance(item,dict) and (item.get("ok") is False or str(item.get("status") or "").lower() in {"failed","error","missing"}): asset_ok=False
    if item is False: asset_ok=False
ready_words={"completed","complete","ok","ready","published","active"}
ready=(version and re.fullmatch(r"[0-9a-f]{40}",commit) and not is_disabled and asset_ok
       and (not status or status in ready_words) and (not stage or stage in ready_words))
if ready: print(version+"|"+commit)
PYBOOT
)"
  [ -n "$beta_line" ] || return 1
  IFS='|' read -r beta_version beta_commit <<EOF_BETA
$beta_line
EOF_BETA

  beta_asset_name="$(coded_m1091v50v_beta_asset_name)"
  beta_url="https://github.com/CodedOnQubic/coded-miner-release/releases/download/${beta_version}/${beta_asset_name}"
  export CODED_RELEASE_CHANNEL="beta"
  export CODED_RELEASE_COMMIT="$beta_commit"
  export CODED_RELEASE_VERSION="$beta_version"
  export CODED_MINER_COMMIT="$beta_commit"
  export CODED_MINER_VERSION="$beta_version"
  export GIT_COMMIT="$beta_commit"
  export RELEASE_VERSION="$beta_version"
  export CODED_RELEASE_ASSET_NAME="$beta_asset_name"
  export CODED_RELEASE_DOWNLOAD_URL="$beta_url"
  export CODED_BETA_SELECTED_NORMAL_FLOW="1"
  return 1
}

'''
    text = replace_once(text, try_anchor, try_override + try_anchor, "initial Beta selection")

    latest_runtime_anchor = '''MINER_PID=$!
echo "$MINER_PID" > "$PID_DIR/miner.pid"

sleep 3

coded_ui_loader 82 "Starting analytics heartbeat"'''
    latest_runtime_override = r'''MINER_PID=$!
echo "$MINER_PID" > "$PID_DIR/miner.pid"

sleep 3

# M1091V67_MAC_LATEST_PRODUCTIVE_EXECUTION_TRUTH
# On Apple Silicon the package launcher may spend time in Hardware Tune before
# exec'ing the final productive binary. Do not freeze the old arm-neon
# compatibility label into Analytics2. Wait on the same PID until its executable
# identity proves Hybrid, Metal or NEON, then feed that exact execution mode to
# sidecar and console. Beta uses the equivalent Python PID->binary bridge.
if [ "$PLATFORM" = "macos-arm64" ]; then
  coded_m1091v67_attempt=0
  coded_m1091v67_resolved=0
  while [ "$coded_m1091v67_attempt" -lt 330 ]; do
    coded_m1091v67_command="$(ps -p "$MINER_PID" -o command= 2>/dev/null || true)"
    coded_m1091v67_exe="${coded_m1091v67_command%% *}"
    coded_m1091v67_name="${coded_m1091v67_exe##*/}"
    case "$coded_m1091v67_name" in
      coded-miner-hybrid)
        SELECTED_BACKEND="hybrid"
        export CODED_BACKEND="hybrid"
        export CODED_KERNEL_BACKEND="hybrid"
        export CODED_SELECTED_BACKEND="hybrid"
        export CODED_HYBRID_CPU_BACKEND="neon"
        export CODED_HYBRID_GPU_BACKEND="metal"
        export CODED_HYBRID_COMPONENT_BACKENDS="neon,metal"
        coded_m1091v67_resolved=1
        ;;
      coded-miner-metal)
        SELECTED_BACKEND="metal"
        export CODED_BACKEND="metal"
        export CODED_KERNEL_BACKEND="metal"
        export CODED_SELECTED_BACKEND="metal"
        unset CODED_HYBRID_CPU_BACKEND CODED_HYBRID_GPU_BACKEND CODED_HYBRID_COMPONENT_BACKENDS
        coded_m1091v67_resolved=1
        ;;
      coded-miner-neon)
        SELECTED_BACKEND="neon"
        export CODED_BACKEND="neon"
        export CODED_KERNEL_BACKEND="neon"
        export CODED_SELECTED_BACKEND="neon"
        unset CODED_HYBRID_CPU_BACKEND CODED_HYBRID_GPU_BACKEND CODED_HYBRID_COMPONENT_BACKENDS
        coded_m1091v67_resolved=1
        ;;
      coded-miner)
        # Legacy public macOS packages used a generic productive binary whose
        # implementation is NEON. Keep this only as an explicit legacy binary
        # fallback; modern V5 packages expose the productive backend in filename.
        SELECTED_BACKEND="neon"
        export CODED_BACKEND="neon"
        export CODED_KERNEL_BACKEND="neon"
        export CODED_SELECTED_BACKEND="neon"
        unset CODED_HYBRID_CPU_BACKEND CODED_HYBRID_GPU_BACKEND CODED_HYBRID_COMPONENT_BACKENDS
        coded_m1091v67_resolved=1
        ;;
    esac
    [ "$coded_m1091v67_resolved" = "1" ] && break
    kill -0 "$MINER_PID" 2>/dev/null || break
    coded_m1091v67_attempt=$((coded_m1091v67_attempt + 1))
    sleep 1
  done
  if [ "$coded_m1091v67_resolved" != "1" ]; then
    coded_m1091v54k_debug "[M1091V67] mac latest productive backend unresolved; keeping Analytics2 fail-closed startup identity"
  else
    coded_m1091v54k_debug "[M1091V67] mac latest productive backend=$SELECTED_BACKEND pid=$MINER_PID"
  fi
fi

coded_ui_loader 82 "Starting analytics heartbeat"'''
    text = replace_once(
        text,
        latest_runtime_anchor,
        latest_runtime_override,
        "mac latest productive execution truth",
    )

    if SOLUTION_AUTHORITY_V3_TASK_SHA not in text or LEGACY_TASK_SHA in text:
        raise RuntimeError("Solution Authority V3 task patch failed")
    for marker in (
        "M1091V64A_V5_SOURCE_COMMIT_AUTOUPDATE",
        "M1091V64B_PLATFORM_EXACT_BETA_AUTOUPDATE",
        "M1091V64C_NETWORK_ACCEPTED_PUBLIC_CONSOLE_REFRESH",
        "M1091V64D_PLATFORM_EXACT_INITIAL_BETA",
        "M1091V67_MAC_LATEST_PRODUCTIVE_EXECUTION_TRUTH",
    ):
        if marker not in text:
            raise RuntimeError("generated runner marker missing: " + marker)
    return linux_v1306(text)


def self_test() -> None:
    fixture = '''#!/usr/bin/env bash
# M1091V51P_FINAL_CHANNEL_AWARE_PUBLIC_AUTOUPDATE
coded_m1091v53a_exec_fresh_runsh() { :; }
coded_m1091v50h_beta_requested() { :; }
coded_m1091v50v_beta_asset_name() { :; }
coded_m1091v50h_try_beta() { :; }
# M1091V50I2_RUN_SH_STATUS_WRAPPER
coded_ensure_public_console() { :; }
coded_ensure_public_console

coded_manifest_commit() { :; }
coded_m1091v51p_platform_asset_name() { :; }
coded_m1091v51p_effective_release_line() { :; }
coded_m1091v51p_kill_current_public_children() { :; }
coded_public_autoupdate_start() { :; }
MINER_PID=$!
echo "$MINER_PID" > "$PID_DIR/miner.pid"

sleep 3

coded_ui_loader 82 "Starting analytics heartbeat"
expected_task_sha="''' + LEGACY_TASK_SHA + '''"
BACKEND=auto
THREADS=0
while [ $# -gt 0 ]; do
  case "$1" in
    -avx2) BACKEND="avx2" ;;
    -avx512) BACKEND="avx512" ;;
    -[0-9]*) THREADS="${1#-}" ;;
    --threads=*) THREADS="${1#--threads=}" ;;
    -t=*) THREADS="${1#-t=}" ;;
  esac
  shift
done
WALLET="${WALLET:-${QUBIC_WALLET:-${CODED_WALLET:-}}}"
pick_exe() {
  :
}
coded_m1091v55b_quiet_stop_public_children() {
  :
}
# M1091V55F_PUBLIC_SIGNAL_TREE_CLEANUP_BEGIN
coded_m1091v55f_stop_child_single() {
    if [ "$tick" -ge 20 ]; then break; fi
}
# M1091V55F_R3_DESCENDANT_GROUP_CLEANUP_BEGIN
# M1091V55F: install terminal traps before first runtime child starts.
'''
    out = transform(fixture, "https://example.invalid/console.py")
    assert LEGACY_TASK_SHA not in out
    assert SOLUTION_AUTHORITY_V3_TASK_SHA in out
    assert '"source_commit","release_commit","commit"' in out
    assert "M1091V64D_PLATFORM_EXACT_INITIAL_BETA" in out
    assert "M1091V67_MAC_LATEST_PRODUCTIVE_EXECUTION_TRUTH" in out
    assert 'SELECTED_BACKEND="hybrid"' in out
    assert 'SELECTED_BACKEND="metal"' in out
    assert 'SELECTED_BACKEND="neon"' in out
    assert "coded_public_autoupdate_start()" in out
    print("FINAL=PASS_RUN_V5_PATCH_SELF_TEST")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input")
    parser.add_argument("--output")
    parser.add_argument("--console-url", default="https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/runtime/coded-public-console-v5.py")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    if not args.input or not args.output:
        parser.error("--input and --output are required unless --self-test is used")
    source = Path(args.input).read_text(encoding="utf-8")
    patched = transform(source, args.console_url)
    Path(args.output).write_text(patched, encoding="utf-8")
    print(MARKER + "=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
