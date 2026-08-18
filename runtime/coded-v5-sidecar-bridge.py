#!/usr/bin/env python3
"""Compatibility bridge for already-built Anthill V5 macOS Beta packages.

Runs the packaged runtime sidecar in-process while adding only exact build
identity (full source commit + SHA256 of the productive binary) to outgoing
analytics JSON. It never changes mining counters, solutions or experiments.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import signal
import sys
import threading
import time
import urllib.request

MARKER = "M1091V65_MAC_BETA_SIDECAR_BUILD_IDENTITY_BRIDGE"
HEX40 = re.compile(r"^[0-9a-fA-F]{40}$")
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        while True:
            chunk = stream.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def full_commit(package: Path) -> str:
    for candidate in (
        package / "release_manifest.json",
        package / "manifest.json",
        package.parent / "release_manifest.json",
    ):
        try:
            data = json.loads(candidate.read_text(encoding="utf-8-sig"))
        except Exception:
            continue
        for key in ("source_commit", "release_commit", "commit", "git_commit"):
            value = str(data.get(key) or "").strip().lower()
            if HEX40.fullmatch(value):
                return value
    for name in ("CODED_RELEASE_COMMIT", "CODED_MINER_COMMIT", "GIT_COMMIT"):
        value = str(os.environ.get(name) or "").strip().lower()
        if HEX40.fullmatch(value):
            return value
    return ""


def patch_dict(value: dict, *, commit: str, digest: str) -> dict:
    value["binary_sha256"] = digest
    value["source_commit"] = commit
    value["git_commit"] = commit
    value["commit"] = commit
    for key in (
        "payload", "frame", "snapshot", "telemetry", "runtime", "data",
        "latest", "worker", "run", "raw", "meta", "analytics_frame", "build",
    ):
        child = value.get(key)
        if isinstance(child, dict):
            patch_dict(child, commit=commit, digest=digest)
    return value


def analytics_url(url: object) -> bool:
    return "/analytics/" in str(url or "")


def patch_data(data: object, url: object, *, commit: str, digest: str):
    if data is None or not analytics_url(url):
        return data
    try:
        raw = data.decode("utf-8") if isinstance(data, (bytes, bytearray)) else str(data)
        obj = json.loads(raw)
        if not isinstance(obj, dict):
            return data
        return json.dumps(
            patch_dict(obj, commit=commit, digest=digest),
            separators=(",", ":"),
        ).encode("utf-8")
    except Exception:
        return data


def install_transport_patch(*, commit: str, digest: str) -> None:
    original_request = urllib.request.Request
    original_urlopen = urllib.request.urlopen

    class PatchedRequest(original_request):
        def __init__(self, url, data=None, headers={}, origin_req_host=None, unverifiable=False, method=None):
            data = patch_data(data, url, commit=commit, digest=digest)
            super().__init__(url, data=data, headers=headers, origin_req_host=origin_req_host, unverifiable=unverifiable, method=method)

    def patched_urlopen(url, data=None, *args, **kwargs):
        try:
            req_url = getattr(url, "full_url", url)
            if data is not None:
                data = patch_data(data, req_url, commit=commit, digest=digest)
            elif isinstance(url, original_request):
                patched = patch_data(getattr(url, "data", None), req_url, commit=commit, digest=digest)
                if patched is not getattr(url, "data", None):
                    url.data = patched
        except Exception:
            pass
        return original_urlopen(url, data=data, *args, **kwargs)

    urllib.request.Request = PatchedRequest
    urllib.request.urlopen = patched_urlopen


def pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except Exception:
        return False


def stop_when_miner_exits(pid: int) -> None:
    while pid_alive(pid):
        time.sleep(1.0)
    os.kill(os.getpid(), signal.SIGTERM)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sidecar", required=True)
    parser.add_argument("--binary", required=True)
    parser.add_argument("--miner-pid", type=int, required=True)
    args = parser.parse_args()

    sidecar = Path(args.sidecar).resolve()
    binary = Path(args.binary).resolve()
    if not sidecar.is_file():
        print(f"{MARKER}=FAIL reason=sidecar_missing path={sidecar}", file=sys.stderr)
        return 70
    if not binary.is_file():
        print(f"{MARKER}=FAIL reason=binary_missing path={binary}", file=sys.stderr)
        return 71

    digest = sha256_file(binary).lower()
    commit = full_commit(sidecar.parent)
    if not HEX64.fullmatch(digest):
        print(f"{MARKER}=FAIL reason=binary_sha_invalid", file=sys.stderr)
        return 72
    if not HEX40.fullmatch(commit):
        print(f"{MARKER}=FAIL reason=source_commit_missing", file=sys.stderr)
        return 73

    os.environ["CODED_BINARY_SHA256"] = digest
    os.environ["CODED_MINER_BINARY"] = str(binary)
    os.environ["CODED_RELEASE_COMMIT"] = commit
    os.environ["CODED_MINER_COMMIT"] = commit
    os.environ["GIT_COMMIT"] = commit
    install_transport_patch(commit=commit, digest=digest)

    threading.Thread(
        target=stop_when_miner_exits,
        args=(args.miner_pid,),
        daemon=True,
    ).start()

    print(f"{MARKER}=STARTED commit={commit} binary_sha256={digest} miner_pid={args.miner_pid}", flush=True)
    runpy.run_path(str(sidecar), run_name="__main__")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
