#!/usr/bin/env bash
# M1091V64_SHARED_RUNSH_V5_AUTOUPDATE_AUTHORITY
#
# Linux and macOS intentionally share one public runner/autoupdate lifecycle.
# The proven runner is pinned below; this compatibility bootstrap applies only
# the V5 identity/authority repairs before executing it:
#   - source_commit/release_commit aware package identity
#   - platform-specific Beta asset readiness
#   - Beta disabled/status/stage fail-closed selection
#   - NETWORK_ACCEPTED-only public SOLS console
#
# This is not a second updater and it never starts experiments.

set -Eeuo pipefail

CORE_COMMIT="d8ddc3f38a105233a6327920373a3ebb2939a55f"
CORE_URL="https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/${CORE_COMMIT}/run.sh"
CONSOLE_URL="${CODED_PUBLIC_CONSOLE_V5_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/runtime/coded-public-console-v5.py}"
TMP_ROOT="${TMPDIR:-/tmp}/coded-runsh-v64.$$"
CORE="$TMP_ROOT/run-core.sh"
PATCHED="$TMP_ROOT/run-v5.sh"

mkdir -p "$TMP_ROOT"
cleanup_v64() {
  rm -rf "$TMP_ROOT" 2>/dev/null || true
}
trap cleanup_v64 EXIT INT TERM HUP

curl -fsSL --retry 3 --connect-timeout 5 --max-time 30 "$CORE_URL" -o "$CORE"

python3 - "$CORE" "$PATCHED" "$CONSOLE_URL" <<'PY'
from pathlib import Path
import sys

src, dst, console_url = map(str, sys.argv[1:4])
s = Path(src).read_text(encoding="utf-8")

required = (
    "M1091V51P_FINAL_CHANNEL_AWARE_PUBLIC_AUTOUPDATE",
    "coded_public_autoupdate_start()",
    "coded_m1091v53a_exec_fresh_runsh()",
    "coded_ensure_public_console",
)
for marker in required:
    if marker not in s:
        raise SystemExit("V64 pinned runner contract missing: " + marker)

# 1) Always refresh the public console from one canonical V5 source before the
# runtime starts.  This also replaces the legacy embedded fallback that mapped
# local total_pass/real300 counters to visible SOLS.
console_anchor = "coded_ensure_public_console\n\ncoded_manifest_commit() {"
console_patch = r'''coded_ensure_public_console

# M1091V64C_NETWORK_ACCEPTED_PUBLIC_CONSOLE_REFRESH
coded_m1091v64c_refresh_public_console() {
  local target tmp url
  target="$INSTALL_DIR/coded-public-console.py"
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

  if grep -Eq 'frame\.get\("(total_pass|real300|real310|real321|solutions|sols)"\).*accepted' "$tmp"; then
    echo "ERROR: legacy local solution acceptance mapping detected"
    rm -f "$tmp" 2>/dev/null || true
    exit 88
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$tmp" <<'PYCHECK' || exit 88
import ast,sys
ast.parse(open(sys.argv[1], encoding="utf-8").read(), filename=sys.argv[1])
PYCHECK
  fi

  chmod 0755 "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$target"
}

coded_m1091v64c_refresh_public_console

coded_manifest_commit() {'''.replace("__CONSOLE_URL__", console_url)
if console_anchor not in s:
    raise SystemExit("V64 console refresh anchor missing")
s = s.replace(console_anchor, console_patch, 1)

# 2) Override the legacy manifest parser. V5 packages use source_commit; older
# packages may still use release_commit/commit. This function is shared by the
# Linux and macOS updater, so one repair fixes both platforms.
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
    d=json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    raise SystemExit(0)
for key in ("source_commit","release_commit","commit","git_commit","miner_commit"):
    v=str(d.get(key) or "").strip().lower()
    if re.fullmatch(r"[0-9a-f]{7,40}", v):
        print(v)
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

  while IFS= read -r mf; do
    [ -s "$mf" ] || continue
    value="$(grep -Eo '"(source_commit|release_commit|commit|git_commit|miner_commit)"[[:space:]]*:[[:space:]]*"[0-9a-fA-F]{7,40}"' "$mf" 2>/dev/null | head -1 | sed -E 's/.*"([0-9a-fA-F]{7,40})".*/\1/' | tr '[:upper:]' '[:lower:]' || true)"
    if printf '%s' "$value" | grep -Eq '^[0-9a-f]{7,40}$'; then
      printf '%s\n' "$value"
      return 0
    fi
  done <<EOF_MANIFESTS
$(find "$dir" -maxdepth 3 -type f \( -name 'release_manifest.json' -o -name 'manifest.json' \) 2>/dev/null || true)
EOF_MANIFESTS

  return 0
}

'''
if manifest_anchor not in s:
    raise SystemExit("V64 manifest parser anchor missing")
s = s.replace(manifest_anchor, manifest_override + manifest_anchor, 1)

# 3) Replace the channel resolver used by the live updater. Beta must be exact,
# not disabled, ready when status/stage are provided, and the current platform
# asset must not be explicitly failed.
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
try: d=json.loads(os.environ.get("STATUS_JSON") or "{}")
except Exception: d={}
latest=d.get("public_latest") or {}
beta=d.get("beta") or {}
disabled=d.get("beta_disabled") or {}

def asset_name(channel):
    if platform=="macos-arm64":
        return "coded-miner-macos-arm64-beta-latest.tar.gz" if channel=="beta" else "coded-miner-macos-arm64-latest.tar.gz"
    if platform.startswith("windows") or platform.startswith("win"):
        return "coded-miner-windows-amd64-beta-latest.tar.gz" if channel=="beta" else "coded-miner-windows-amd64-latest.tar.gz"
    return "coded-miner-beta-latest.tar.gz" if channel=="beta" else "coded-miner-latest.tar.gz"

def platform_asset_ok(obj):
    assets=obj.get("assets") if isinstance(obj.get("assets"),dict) else {}
    keys=("macos_arm64","macos-arm64","macos","mac") if platform=="macos-arm64" else (("windows","windows_amd64") if platform.startswith(("win","windows")) else ("linux","hive"))
    found=False
    for key in keys:
        item=assets.get(key)
        if isinstance(item,dict):
            found=True
            if item.get("ok") is False or str(item.get("status") or "").lower() in {"failed","error","missing"}:
                return False
        elif isinstance(item,bool):
            found=True
            if not item: return False
    return True if found else True

commit=str(beta.get("commit") or beta.get("source_commit") or "").strip().lower()
version=str(beta.get("version") or "").strip()
status=str(beta.get("status") or "").strip().lower()
stage=str(beta.get("stage") or "").strip().lower()
disabled_commit=str(disabled.get("commit") or "").strip().lower()
is_disabled=bool(disabled.get("disabled")) and (not disabled_commit or disabled_commit==commit)
ready_words={"completed","complete","ok","ready","published","active"}
ready=(
    want_beta and version and re.fullmatch(r"[0-9a-f]{40}",commit) and not is_disabled
    and (not status or status in ready_words)
    and (not stage or stage in ready_words)
    and platform_asset_ok(beta)
)
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
if effective_anchor not in s:
    raise SystemExit("V64 effective release anchor missing")
s = s.replace(effective_anchor, effective_override + effective_anchor, 1)

# 4) The initial Beta selection happens before the updater functions above are
# reached. Replace it too so a Mac never gates itself on beta.assets.linux.ok.
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
try: d=json.loads(os.environ.get("STATUS_JSON") or "{}")
except Exception: d={}
beta=d.get("beta") or {}; disabled=d.get("beta_disabled") or {}
commit=str(beta.get("commit") or beta.get("source_commit") or "").strip().lower()
version=str(beta.get("version") or "").strip()
status=str(beta.get("status") or "").lower(); stage=str(beta.get("stage") or "").lower()
disabled_commit=str(disabled.get("commit") or "").strip().lower()
is_disabled=bool(disabled.get("disabled")) and (not disabled_commit or disabled_commit==commit)
ready_words={"completed","complete","ok","ready","published","active"}
assets=beta.get("assets") if isinstance(beta.get("assets"),dict) else {}
keys=("macos_arm64","macos-arm64","macos","mac") if platform=="macos-arm64" else ("linux","hive")
asset_ok=True
for key in keys:
    item=assets.get(key)
    if isinstance(item,dict) and (item.get("ok") is False or str(item.get("status") or "").lower() in {"failed","error","missing"}): asset_ok=False
    if isinstance(item,bool) and not item: asset_ok=False
ready=version and re.fullmatch(r"[0-9a-f]{40}",commit) and not is_disabled and asset_ok and (not status or status in ready_words) and (not stage or stage in ready_words)
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
if try_anchor not in s:
    raise SystemExit("V64 initial beta anchor missing")
s = s.replace(try_anchor, try_override + try_anchor, 1)

Path(dst).write_text(s, encoding="utf-8")
PY

chmod 0755 "$PATCHED"
bash -n "$PATCHED"

grep -Fq 'M1091V64A_V5_SOURCE_COMMIT_AUTOUPDATE' "$PATCHED"
grep -Fq 'M1091V64B_PLATFORM_EXACT_BETA_AUTOUPDATE' "$PATCHED"
grep -Fq 'M1091V64C_NETWORK_ACCEPTED_PUBLIC_CONSOLE_REFRESH' "$PATCHED"
grep -Fq 'M1091V64D_PLATFORM_EXACT_INITIAL_BETA' "$PATCHED"

trap - EXIT INT TERM HUP
exec bash "$PATCHED" "$@"
