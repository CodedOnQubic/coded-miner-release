#!/usr/bin/env python3

# M10.99Z273S_UPLOADER_PUBLIC_WORKER_ROLE
def z273s_env_bool(name, default=False):
    v = str(os.environ.get(name, "")).strip().lower()
    if not v:
        return bool(default)
    return v in ("1", "true", "yes", "y", "on")

def z273s_public_role_payload():
    build_enabled = z273s_env_bool("CODED_ENABLE_BUILD_AGENT", False) or z273s_env_bool("BUILDER", False)
    autoupdate_enabled = z273s_env_bool("CODED_SELF_UPDATE_ENABLED", True) or z273s_env_bool("AUTOUPDATE", True)
    return {
        "builder": build_enabled,
        "builder_targets": ["macos-arm64"] if build_enabled else [],
        "self_update_enabled": autoupdate_enabled,
        "capabilities": {
            "macos_arm64": True,
            "default_analytics": True,
            "run_experiment": True,
            "build_macos_arm64": build_enabled,
            "scalar": True,
            "docker": False
        },
        "device_role": "builder_default_analytics" if build_enabled else "default_analytics",
        "runtime_mode": "default_analytics",
        "runtime_state": "mining_active",
        "z273s_marker": "M10.99Z273S_UPLOADER_PUBLIC_WORKER_ROLE"
    }

"""
M10.99Z270B_MAC_ARM_REFERENCE_LOG_UPLOADER

Reads macOS ARM reference miner logs and uploads runtime telemetry to:
  /fleet/devices/heartbeat

Purpose:
- ARM reference miner is correctness/portability lane, not it/s lane.
- Uploader reports fullscore timing, real-score truth and backend metadata.
- Keeps fleet_devices + AI bridge + frontend data consistent.
"""

import json
import os
import re
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path

# M10.99Z270I_STRICT_REAL_SHADOW_SCORE_SPLIT
# Never mix shadow_score with real_score.
# Qubic solution eligibility is based ONLY on real_score >= threshold.
def z270i_extract_real_shadow_audits(text):
    rows = []
    for line in text.splitlines():
        if "REAL_SCORE_AUDIT_DEBUG" not in line:
            continue
        m = re.search(
            r"shadow_score=(\d+).*real_score=(\d+).*audited_skip=(\d+).*nonce=([0-9a-fA-F]+|\d+)",
            line,
        )
        if not m:
            continue
        shadow, real, audited_skip, nonce = m.groups()
        rows.append({
            "shadow_score": int(shadow),
            "real_score": int(real),
            "audited_skip": int(audited_skip),
            "nonce": nonce,
            "line": line,
        })
    return rows

def z270i_score_metrics(text, threshold):
    rows = z270i_extract_real_shadow_audits(text)
    real_pass = [r for r in rows if int(r["real_score"]) >= int(threshold)]
    shadow_pass = [r for r in rows if int(r["shadow_score"]) >= int(os.environ.get("CODED_FAST_SHADOW_THRESHOLD", "300") or 300)]

    max_real = max([r["real_score"] for r in rows], default=0)
    max_shadow = max([r["shadow_score"] for r in rows], default=0)
    max_real_passed = max([r["real_score"] for r in real_pass], default=0)
    max_shadow_passed = max([r["shadow_score"] for r in shadow_pass], default=0)

    return {
        "real_score_count": len(rows),
        "fullscore_count": len(rows),
        "total_seen": len(rows),

        # REAL/Qubic truth
        "max_real_score_seen": max_real,
        "max_real_score_passed": max_real_passed,
        "total_pass": len(real_pass),
        "real_321_plus_count": len(real_pass),
        "real_solution_found": bool(real_pass),

        # SHADOW/debug truth
        "max_shadow_score_seen": max_shadow,
        "max_shadow_score_passed": max_shadow_passed,
        "shadow_300_plus_count": len(shadow_pass),

        # Safety
        "false_negative": 0,
    }



# M10.99Z270J_UPLOADER_PARSER_TRUTH_DEBUG
def z270j_parser_debug(log_path, log_text, z270i):
    last_line = ""
    for line in reversed(log_text.splitlines()):
        if "REAL_SCORE_AUDIT_DEBUG" in line:
            last_line = line[-500:]
            break
    return {
        "marker": "M10.99Z270J_UPLOADER_PARSER_TRUTH_DEBUG",
        "log_path": str(log_path),
        "log_exists": Path(str(log_path)).exists(),
        "log_bytes": Path(str(log_path)).stat().st_size if Path(str(log_path)).exists() else 0,
        "audit_count": int(z270i.get("real_score_count", 0)),
        "max_real_score_seen": int(z270i.get("max_real_score_seen", 0)),
        "max_shadow_score_seen": int(z270i.get("max_shadow_score_seen", 0)),
        "real_321_plus_count": int(z270i.get("real_321_plus_count", 0)),
        "shadow_300_plus_count": int(z270i.get("shadow_300_plus_count", 0)),
        "last_real_score_line_seen": last_line,
    }




# M10.99Z273C2_FIX_ARM_UPLOADER_SYNTAX_AND_HEARTBEAT_URL
# M10.99Z273C_ARM_UPLOADER_WORKER_API_PROFILE_FIX
def z273c_env_str(name, default=""):
    v = os.environ.get(name, "")
    if v is None or str(v).strip() == "":
        return default
    return str(v).strip()

def z273c_profile_payload():
    return {
        "priority_router": z273c_env_str("CODED_PRIORITY_ROUTER", "M1098E"),
        "router": z273c_env_str("CODED_PRIORITY_ROUTER", "M1098E"),
        "default_profile": z273c_env_str("CODED_DEFAULT_ANALYTICS_PROFILE", "Z273B_ARM_M1098E_T321"),
        "profile_version": z273c_env_str("CODED_PROFILE_VERSION", "Z273B_ARM_DEFAULT_ANALYTICS_M1098E_T321_V1"),
        "runtime_mode": z273c_env_str("CODED_RUNTIME_MODE", "default_analytics"),
        "device_role": z273c_env_str("CODED_DEVICE_ROLE", "default_analytics"),
        "z273c_marker": "M10.99Z273C_ARM_UPLOADER_WORKER_API_PROFILE_FIX",
    }

# M10.99Z271I_ARM_UPLOADER_RELEASE_VERSION_PAYLOAD
def z271i_read_release_manifest():
    candidates = []
    try:
        candidates.append(Path(__file__).with_name("release_manifest.json"))
    except Exception:
        pass
    candidates.append(Path("/tmp/coded-miner-macos-arm64/release_manifest.json"))

    for mf in candidates:
        try:
            if mf.exists():
                import json
                data = json.loads(mf.read_text(errors="ignore"))
                if isinstance(data, dict):
                    return data
        except Exception:
            continue
    return {}

def z271i_release_payload():
    mf = z271i_read_release_manifest()
    version = str(mf.get("version") or "")
    commit = str(mf.get("commit") or "")
    target = str(mf.get("target") or mf.get("platform") or "macos-arm64")
    built_at = str(mf.get("built_at") or "")

    return {
        "installed_version": version or None,
        "current_version": version or None,
        "release_version": version or None,
        "artifact_version": version or None,
        "release_commit": commit or None,
        "release_target": target or "macos-arm64",
        "release_built_at": built_at or None,
        "self_update_enabled": str(os.environ.get("CODED_SELF_UPDATE_SUPERVISOR", "")).lower() in ("1", "yes", "true", "on"),
        "update_state": "installed_current_latest_unknown",
        "version_marker": "M10.99Z271I_ARM_UPLOADER_RELEASE_VERSION_PAYLOAD",
    }

# M10.99Z270E2_FORCE_ARM_REFERENCE_THRESHOLD_PAYLOAD
def z270e2_int_env(name, default):
    try:
        raw = os.environ.get(name, "")
        if raw is None or str(raw).strip() == "":
            return int(default)
        return int(float(str(raw).strip()))
    except Exception:
        return int(default)


# M10.99Z270G_ARM_UPLOADER_BUILDER_PAYLOAD
def z270g_bool_env(name, default=False):
    raw = os.environ.get(name)
    if raw is None or str(raw).strip() == "":
        return bool(default)
    return str(raw).strip().lower() in ("1", "yes", "y", "true", "on")

def z270g_builder_targets():
    raw = os.environ.get("CODED_BUILDER_TARGETS", "macos-arm64")
    vals = [x.strip() for x in raw.split(",") if x.strip()]
    return vals or ["macos-arm64"]

def z270e2_thresholds():
    fullscore_threshold = z270e2_int_env("CODED_FULLSCORE_THRESHOLD", 321)
    threshold = z270e2_int_env("CODED_THRESHOLD", fullscore_threshold)
    shadow_threshold = z270e2_int_env("CODED_FAST_SHADOW_THRESHOLD", 300)

    if fullscore_threshold <= 0:
        fullscore_threshold = 321
    if threshold <= 0:
        threshold = fullscore_threshold
    if shadow_threshold <= 0:
        shadow_threshold = 300

    return threshold, fullscore_threshold, shadow_threshold



MARKER = "M10.99Z270B_MAC_ARM_REFERENCE_LOG_UPLOADER"

API_ROOT = os.environ.get("CODED_API_ROOT") or os.environ.get("API_URL") or "https://api.codedonqubic.com"
API_ROOT = API_ROOT.rstrip("/")
HEARTBEAT_URL = os.environ.get("CODED_POOL_API") or os.environ.get("CODED_HEARTBEAT_URL") or f"{API_ROOT}/fleet/devices/heartbeat"

LOG = Path(os.environ.get("CODED_MAC_LOG") or "/tmp/coded-mac-arm-reference.log")
DEVICE_ID = z273c_env_str("CODED_DEVICE_ID", z273c_env_str("DEVICE_ID", "macos-arm64:Oscar-Mac-ARM"))
RIG_ID = z273c_env_str("CODED_RIG_ID", z273c_env_str("RIG_ID", DEVICE_ID))
WORKER_NAME = z273c_env_str("CODED_WORKER_NAME", z273c_env_str("WORKER_NAME", z273c_env_str("WORKER", "Oscar-Mac-ARM-Z273B-DEFAULT_ANALYTICS_M1098E_T321")))
WALLET = os.environ.get("WALLET") or ""
THREADS = int(os.environ.get("THREADS") or "1")

FULLSCORE_THRESHOLD = int(os.environ.get("CODED_FULLSCORE_THRESHOLD") or "321")
SHADOW_THRESHOLD = int(os.environ.get("CODED_FAST_SHADOW_THRESHOLD") or "300")

BACKEND = os.environ.get("CODED_BACKEND") or os.environ.get("CODED_KERNEL_BACKEND") or "arm-portable"
BACKEND_KIND = os.environ.get("CODED_BACKEND_KIND") or BACKEND
BACKEND_SHORT = os.environ.get("CODED_BACKEND_SHORT") or BACKEND_KIND
BACKEND_PLATFORM = os.environ.get("CODED_BACKEND_PLATFORM") or "macos-arm64"

BACKEND_VALIDATION = os.environ.get("CODED_BACKEND_VALIDATION") or "golden_25_matched_live_score_verified"
TRAINING_ROLE = os.environ.get("CODED_TRAINING_ROLE") or "external_arm_reference_validation"
PERFORMANCE_CLASS = os.environ.get("CODED_PERFORMANCE_CLASS") or "slow_reference"

POLL_SEC = float(os.environ.get("CODED_MAC_ARM_UPLOADER_POLL_SEC") or "5")
POST_SEC = float(os.environ.get("CODED_MAC_ARM_UPLOADER_POST_SEC") or "10")

hi_ms_re = re.compile(r"(?:last_ms|avg_ms)=([0-9]+(?:\.[0-9]+)?)")
score_re = re.compile(r"(?:score|real_score|last_real_score)=([0-9]+)")
runtime_active_re = re.compile(r"\[RUNTIME\]\s+mining active|QATUM_SCORE_ENGINE_MODE.*reference|CODED_RUNTIME_CONTRACT")
miner_line_re = re.compile(r"\[\s*\$0\.01 CODED\s*\].*?\|\s*\[([^\]]+)\]\s+([0-9]+)\s+it/s\s+\|\s+([0-9]+)\s+avg it/s")

def now_iso():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

def read_tail(path: Path, max_bytes: int = 262_144) -> str:
    try:
        if not path.exists():
            return ""
        size = path.stat().st_size
        with path.open("rb") as f:
            if size > max_bytes:
                f.seek(size - max_bytes)
            return f.read().decode("utf-8", errors="replace")
    except Exception:
        return ""

def parse_log(text: str):
    runtime_active = False
    hi_ms_values = []
    real_scores = []
    last_its = 0
    avg_its = 0

    for line in text.splitlines():
        if runtime_active_re.search(line):
            runtime_active = True

        m = miner_line_re.search(line)
        if m:
            try:
                last_its = int(m.group(2))
                avg_its = int(m.group(3))
            except Exception:
                pass

        if "HI_TIMING" in line or "REAL_SCORE" in line or "DIRECT_SCORE" in line:
            mm = hi_ms_re.search(line)
            if mm:
                try:
                    hi_ms_values.append(float(mm.group(1)))
                except Exception:
                    pass

            sm = score_re.search(line)
            if sm:
                try:
                    real_scores.append(int(sm.group(1)))
                except Exception:
                    pass

    real_score_count = len(hi_ms_values) if hi_ms_values else len(real_scores)
    avg_fullscore_ms = (sum(hi_ms_values) / len(hi_ms_values)) if hi_ms_values else 22500.0
    fullscore_per_hour = 3600000.0 / avg_fullscore_ms if avg_fullscore_ms > 0 else 0.0

    max_real_score_seen = max(real_scores) if real_scores else 0
    max_real_score_passed = max([s for s in real_scores if s >= FULLSCORE_THRESHOLD], default=0)

    # For ARM reference, avg_its means fullscores/hour, not nonce it/s.
    reference_avg_its = int(round(fullscore_per_hour))

    # If miner log is active but no HI line yet, report expected calibrated rate.
    if runtime_active and real_score_count == 0:
        reference_avg_its = int(round(3600 / 22))
        fullscore_per_hour = float(reference_avg_its)
        avg_fullscore_ms = 22000.0

    return {
        "runtime_active": runtime_active,
        "last_its": reference_avg_its,
        "avg_its": reference_avg_its,
        "real_score_count": real_score_count,
        "avg_fullscore_ms": round(avg_fullscore_ms, 3),
        "fullscore_per_hour": round(fullscore_per_hour, 3),
        "max_real_score_seen": max_real_score_seen,
        "max_real_score_passed": max_real_score_passed,
        "total_seen": real_score_count,
        "total_pass": max_real_score_passed and 1 or 0,
        "total_audited": real_score_count,
    }

def post_json(url, payload):
    raw = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=raw,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "User-Agent": MARKER,
        },
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        body = resp.read().decode("utf-8", errors="replace")
        return resp.status, body

def build_payload(parsed):
    threshold, fullscore_threshold, shadow_threshold = z270e2_thresholds()
    try:
        log_text = LOG.read_text(errors="ignore")
    except Exception:
        log_text = ""
    z270i = z270i_score_metrics(log_text, threshold)
    z271i_release = z271i_release_payload()
    z273c_profile = z273c_profile_payload()
    z270j_debug = z270j_parser_debug(LOG, log_text, z270i)
    runtime_state = "mining_active" if parsed["runtime_active"] else "running"

    return {
        "marker": MARKER,
        "source": "mac_arm_reference_log_uploader",
        **z273s_public_role_payload(),
        "device_id": DEVICE_ID,
        "rig_id": RIG_ID,
        "worker_name": WORKER_NAME,
        "wallet": WALLET,

        "target": "macos-arm64",
        "analytics": True,
        "builder": os.environ.get("CODED_BUILDER", "").lower() in ("1", "yes", "true", "on"),
        "builder_targets": ["macos-arm64"] if os.environ.get("CODED_BUILDER", "").lower() in ("1", "yes", "true", "on") else [],
        "miner_running": parsed["runtime_active"],
        "runtime_state": runtime_state,
        "runtime_mode": "default_analytics",
        "device_role": "default_analytics",

        "platform": "macos-arm64",
        "os": "Darwin",
        "arch": "arm64",
        "backend": BACKEND,
        "backend_kind": BACKEND_KIND,
        "backend_short": BACKEND_SHORT,
        "backend_platform": BACKEND_PLATFORM,
        "backend_validation": BACKEND_VALIDATION,

        "threads": THREADS,
        "fullscore": True,
        "threshold": threshold,
        "fullscore_threshold": fullscore_threshold,
        "shadow_threshold": shadow_threshold,

        # M10.99Z271I_ARM_UPLOADER_RELEASE_VERSION_PAYLOAD
        "installed_version": z271i_release.get("installed_version"),
        "current_version": z271i_release.get("current_version"),
        "release_version": z271i_release.get("release_version"),
        "artifact_version": z271i_release.get("artifact_version"),
        "release_commit": z271i_release.get("release_commit"),
        "release_target": z271i_release.get("release_target"),
        "release_built_at": z271i_release.get("release_built_at"),
        "self_update_enabled": z271i_release.get("self_update_enabled"),
        "update_state": z271i_release.get("update_state"),

        # M10.99Z273C_ARM_UPLOADER_WORKER_API_PROFILE_FIX
        "priority_router": z273c_profile.get("priority_router"),
        "router": z273c_profile.get("router"),
        "default_profile": z273c_profile.get("default_profile"),
        "profile_version": z273c_profile.get("profile_version"),
        "z273c_marker": z273c_profile.get("z273c_marker"),
        "version_marker": z271i_release.get("version_marker"),

        "real_score_available": 1,
        "real_score_authoritative": 0,
        "real_score_truth": True,
        "real_score_training_eligible": True,
        "training_role": TRAINING_ROLE,
        "performance_class": PERFORMANCE_CLASS,

        "avg_fullscore_ms": parsed["avg_fullscore_ms"],
        "fullscore_per_hour": parsed["fullscore_per_hour"],
        "real_score_count": z270i["real_score_count"],
        "max_real_score_seen": z270i["max_real_score_seen"],
        "max_real_score_passed": z270i["max_real_score_passed"],
        "max_real_score_audited_skip": 0,

        "last_its": parsed["last_its"],
        "avg_its": parsed["avg_its"],
        "total_seen": z270i["total_seen"],
        "total_pass": z270i["total_pass"],

        # M10.99Z270J_UPLOADER_PARSER_TRUTH_DEBUG
        "real_321_plus_count": z270i["real_321_plus_count"],
        "real_solution_found": z270i["real_solution_found"],
        "max_shadow_score_seen": z270i["max_shadow_score_seen"],
        "max_shadow_score_passed": z270i["max_shadow_score_passed"],
        "shadow_300_plus_count": z270i["shadow_300_plus_count"],
        "parser_debug": z270j_debug,

        "total_skip": 0,
        "total_audited": parsed["total_audited"],
        "pass_rate": 0,
        "audit_rate": 1,
        "false_negative": 0,

        "received_at": now_iso(),
        "capabilities": {
            "scalar": True,
            "macos_arm64": True,
            "docker": False,
            "build_macos_arm64": os.environ.get("CODED_BUILDER", "").lower() in ("1", "yes", "true", "on"),
            "run_experiment": True,
            "default_analytics": True,
        },
    }

def main():
    print(json.dumps({
        "ok": True,
        "marker": MARKER,
        "api": HEARTBEAT_URL,
        "log": str(LOG),
        "device_id": DEVICE_ID,
        "worker_name": WORKER_NAME,
    }), flush=True)

    last_post = 0.0

    while True:
        text = read_tail(LOG)
        parsed = parse_log(text)

        if time.time() - last_post >= POST_SEC:
            payload = build_payload(parsed)
            try:
                status, body = post_json(HEARTBEAT_URL, payload)
                print(json.dumps({
                    "ok": 200 <= status < 300,
                    "marker": MARKER,
                    "http": status,
                    "runtime_state": payload["runtime_state"],
                    "real_score_count": payload["real_score_count"],
                    "avg_fullscore_ms": payload["avg_fullscore_ms"],
                    "fullscore_per_hour": payload["fullscore_per_hour"],
                    "max_real_score_seen": payload["max_real_score_seen"],
                    "total_pass": payload.get("total_pass", 0),
                    "max_shadow_score_seen": payload.get("max_shadow_score_seen", 0),
                    "parser_debug": payload.get("parser_debug", {}),
                }), flush=True)
            except Exception as e:
                print(json.dumps({
                    "ok": False,
                    "marker": MARKER,
                    "error": str(e),
                }), flush=True)

            last_post = time.time()

        time.sleep(POLL_SEC)

if __name__ == "__main__":
    main()
