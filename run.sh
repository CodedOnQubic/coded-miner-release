#!/usr/bin/env bash
# M1091V70_RUNTIME_POLICY_AUTHORITY_V1
#
# Cross-platform public Unix entrypoint for Linux and macOS.
# Desired startup policy is resolved before the proven V5 runner snapshots
# backend intent. Execution truth remains owned by Hardware Tune / the final
# productive binary and Analytics2; this wrapper never writes execution labels.

set -Eeuo pipefail

CODED_PUBLIC_RUNNER_BASE_COMMIT="5e898b60779ea163b07bb44dd7a3e1186b414f8b"
CODED_PUBLIC_RUNNER_BASE_URL="https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/${CODED_PUBLIC_RUNNER_BASE_COMMIT}/run.sh"
CODED_RUNTIME_POLICY_SCHEMA="coded.runtime.policy.v1"
export CODED_RUNTIME_POLICY_SCHEMA

coded_v70_identity_from_config() {
  python3 - <<'PY' 2>/dev/null || true
import json, os, re
raws = [
    os.environ.get("CUSTOM_CONFIG", ""),
    os.environ.get("CUSTOM_USER_CONFIG", ""),
    os.environ.get("HIVE_CUSTOM_CONFIG", ""),
    os.environ.get("USER_CONFIG", ""),
    os.environ.get("MINER_CUSTOM_CONFIG", ""),
    os.environ.get("CODED_USER_CONFIG", ""),
    os.environ.get("EXTRA_CONFIG", ""),
]
worker_keys = ("worker", "worker_name", "WORKER", "WORKER_NAME", "CODED_WORKER", "CODED_WORKER_NAME")
rig_keys = ("rig_id", "RIG_ID", "CODED_RIG_ID")
worker = ""
rig = ""
for raw in raws:
    raw = (raw or "").strip()
    if not raw:
        continue
    obj = None
    try:
        obj = json.loads(raw)
    except Exception:
        obj = None
    if isinstance(obj, dict):
        for key in rig_keys:
            value = obj.get(key)
            if value not in (None, ""):
                rig = str(value).strip()
                break
        for key in worker_keys:
            value = obj.get(key)
            if value not in (None, ""):
                worker = str(value).strip()
                break
    if not rig:
        m = re.search(r'(?i)["\']?(?:coded_)?rig_id["\']?\s*[:=]\s*["\']?([A-Za-z0-9_.:-]{1,128})', raw)
        if m:
            rig = m.group(1)
    if not worker:
        m = re.search(r'(?i)["\']?(?:coded_)?worker(?:_name)?["\']?\s*[:=]\s*["\']?([A-Za-z0-9_.:-]{1,128})', raw)
        if m:
            worker = m.group(1)
    if rig or worker:
        break
print(rig)
print(worker)
PY
}

coded_v70_parse_policy() {
  POLICY_JSON="$1" python3 - <<'PY' 2>/dev/null || true
import json, os
try:
    data = json.loads(os.environ.get("POLICY_JSON") or "{}")
except Exception:
    raise SystemExit(0)
if data.get("ok") is not True or data.get("schema") != "coded.runtime.policy.v1":
    raise SystemExit(0)
managed = bool(data.get("managed"))
valid = bool(data.get("valid"))
policy = data.get("policy") if isinstance(data.get("policy"), dict) else {}
matched = data.get("matched") if isinstance(data.get("matched"), dict) else {}
backend = str(policy.get("backend") or "").strip().lower()
canonical_rig = str(matched.get("rig_id") or "").strip()
canonical_worker = str(matched.get("worker_name") or "").strip()
profile = str(policy.get("profile_version") or "").strip()
print("1" if managed else "0")
print("1" if valid else "0")
print(backend)
print(canonical_rig)
print(canonical_worker)
print(profile)
PY
}

coded_v70_policy_apply() {
  local rig worker config_identity config_rig config_worker pool query url live_json parse
  local managed valid backend canonical_rig canonical_worker profile source cache_root cache_key cache_file
  local -a filtered

  rig="${CODED_RIG_ID:-${RIG_ID:-${HIVE_RIG_ID:-}}}"
  worker="${WORKER:-${QUBIC_WORKER:-${CODED_WORKER:-${CODED_WORKER_NAME:-${WORKER_NAME:-${RIG_NAME:-}}}}}}"

  if { [ -z "$rig" ] || [ -z "$worker" ]; } && command -v python3 >/dev/null 2>&1; then
    config_identity="$(coded_v70_identity_from_config)"
    config_rig="$(printf '%s\n' "$config_identity" | sed -n '1p')"
    config_worker="$(printf '%s\n' "$config_identity" | sed -n '2p')"
    [ -n "$rig" ] || rig="$config_rig"
    [ -n "$worker" ] || worker="$config_worker"
  fi

  [ -n "$rig" ] || rig="$worker"
  [ -n "$worker" ] || worker="$rig"
  [ -n "$rig" ] || return 0

  cache_root="${CODED_RUNTIME_POLICY_CACHE_DIR:-${HOME:-/tmp}/.coded-miner/runtime-policy}"
  cache_key="$(printf '%s' "${rig:-$worker}" | tr -cd 'A-Za-z0-9_.-' | cut -c1-96)"
  [ -n "$cache_key" ] || cache_key="coded-worker"
  cache_file="$cache_root/${cache_key}.json"
  umask 077
  mkdir -p "$cache_root" 2>/dev/null || true

  pool="${CODED_POOL_API_URL:-${POOL_API_URL:-${CODED_POOL_API_BASE:-https://api.codedonqubic.com}}}"
  pool="${pool%/}"
  case "$pool" in */analytics) pool="${pool%/analytics}" ;; esac
  url="${CODED_RUNTIME_POLICY_URL:-${pool}/analytics2/runtime-policy}"

  query="$(python3 - "$rig" "$worker" <<'PYQ' 2>/dev/null || true
import sys
from urllib.parse import urlencode
rig = (sys.argv[1] or "").strip()
worker = (sys.argv[2] or "").strip()
params = {}
if rig: params["rig_id"] = rig
if worker: params["worker_name"] = worker
print(urlencode(params))
PYQ
)"

  live_json=""
  if [ -n "$query" ]; then
    live_json="$(curl -fsSL --retry 2 --connect-timeout 4 --max-time 10 "${url}?${query}" 2>/dev/null || true)"
  fi

  source="live"
  parse=""
  if [ -n "$live_json" ]; then
    parse="$(coded_v70_parse_policy "$live_json")"
    if [ -n "$parse" ]; then
      managed="$(printf '%s\n' "$parse" | sed -n '1p')"
      if [ "$managed" = "1" ]; then
        printf '%s\n' "$live_json" > "$cache_file" 2>/dev/null || true
      else
        rm -f "$cache_file" 2>/dev/null || true
      fi
    fi
  fi

  if [ -z "$parse" ] && [ -s "$cache_file" ]; then
    source="cache"
    live_json="$(cat "$cache_file" 2>/dev/null || true)"
    parse="$(coded_v70_parse_policy "$live_json")"
  fi

  [ -n "$parse" ] || return 0

  managed="$(printf '%s\n' "$parse" | sed -n '1p')"
  valid="$(printf '%s\n' "$parse" | sed -n '2p')"
  backend="$(printf '%s\n' "$parse" | sed -n '3p')"
  canonical_rig="$(printf '%s\n' "$parse" | sed -n '4p')"
  canonical_worker="$(printf '%s\n' "$parse" | sed -n '5p')"
  profile="$(printf '%s\n' "$parse" | sed -n '6p')"

  [ "$managed" = "1" ] || return 0
  if [ "$valid" != "1" ]; then
    echo "ERROR: managed CODED runtime policy is inconsistent; refusing AUTO/backend fallback" >&2
    echo "Policy identity: rig=${canonical_rig:-$rig} worker=${canonical_worker:-$worker} profile=${profile:-unknown}" >&2
    exit 78
  fi

  case "$backend" in
    auto|scalar|avx2|avx512|neon|metal|cuda|hybrid) ;;
    *)
      echo "ERROR: managed CODED runtime policy returned unsupported backend '$backend'" >&2
      exit 78
      ;;
  esac

  export CODED_RUNTIME_POLICY_MANAGED="1"
  export CODED_RUNTIME_POLICY_VALID="1"
  export CODED_RUNTIME_POLICY_SOURCE="$source"
  export CODED_RUNTIME_POLICY_AUTHORITY="miner_default_profiles"
  export CODED_RUNTIME_POLICY_BACKEND="$backend"
  export CODED_RUNTIME_POLICY_PROFILE="$profile"
  [ -n "$canonical_rig" ] && export CODED_RUNTIME_POLICY_RIG_ID="$canonical_rig"
  [ -n "$canonical_worker" ] && export CODED_RUNTIME_POLICY_WORKER_NAME="$canonical_worker"

  # Request authority: these are inputs. CODED_KERNEL_BACKEND and
  # CODED_SELECTED_BACKEND remain execution outputs and are deliberately not set.
  export CODED_HARDWARE_TUNE_REQUESTED_BACKEND="$backend"
  export CODED_PUBLIC_BACKEND_REQUEST_SNAPSHOT="$backend"
  export BACKEND="$backend"

  # A managed policy must not be undone by legacy shorthand/--backend flags
  # later in the pinned runner's argument parser. Non-backend arguments remain
  # byte-for-byte in order.
  filtered=()
  for arg in "$@"; do
    case "$arg" in
      -auto|-scalar|-avx2|-avx512|-neon|-metal|-cuda|-hybrid|--backend=*|-backend=*) ;;
      *) filtered+=("$arg") ;;
    esac
  done

  CODED_V70_FILTERED_ARGC="${#filtered[@]}"
  export CODED_V70_FILTERED_ARGC
  CODED_V70_FILTERED_ARGS_FILE="${TMPDIR:-/tmp}/coded-v70-args-${UID:-0}-$$"
  export CODED_V70_FILTERED_ARGS_FILE
  : > "$CODED_V70_FILTERED_ARGS_FILE"
  for arg in "${filtered[@]}"; do printf '%s\0' "$arg" >> "$CODED_V70_FILTERED_ARGS_FILE"; done
}

coded_v70_policy_apply "$@"

# Rebuild argv only when a managed policy filtered backend selectors.
if [ "${CODED_RUNTIME_POLICY_MANAGED:-0}" = "1" ] && [ -f "${CODED_V70_FILTERED_ARGS_FILE:-}" ]; then
  coded_v70_args=()
  while IFS= read -r -d '' coded_v70_arg; do coded_v70_args+=("$coded_v70_arg"); done < "$CODED_V70_FILTERED_ARGS_FILE"
  rm -f "$CODED_V70_FILTERED_ARGS_FILE" 2>/dev/null || true
  set -- "${coded_v70_args[@]}"
fi

# Delegate to the last proven public runner. Its own channel-aware updater still
# returns to main/run.sh, so every real lifecycle restart resolves policy again.
coded_v70_base="${TMPDIR:-/tmp}/coded-public-runner-${CODED_PUBLIC_RUNNER_BASE_COMMIT}.sh"
coded_v70_tmp="${coded_v70_base}.tmp.$$"
if [ ! -s "$coded_v70_base" ]; then
  curl -fsSL --retry 3 --connect-timeout 5 --max-time 30 "${CODED_PUBLIC_RUNNER_BASE_URL}?cb=$(date +%s)" -o "$coded_v70_tmp"
  grep -Fq 'M1091V65_MAC_BETA_PRODUCTIVE_RUNTIME_BRIDGE' "$coded_v70_tmp"
  mv -f "$coded_v70_tmp" "$coded_v70_base"
fi
chmod 0755 "$coded_v70_base" 2>/dev/null || true
exec bash "$coded_v70_base" "$@"
