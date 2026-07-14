#!/usr/bin/env python3

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / "run.ps1"

if not RUNNER.is_file():
    raise SystemExit(
        f"ERROR: missing runner: {RUNNER}"
    )

source = RUNNER.read_text(
    encoding="utf-8",
)

required = (
    "M1091V63G2A3E_WINDOWS8_SAFE_RELEASE_IDENTITY_UPDATE",
    "M1091V63G2A3E_WINDOWS_RELEASE_IDENTITY",
    "M1091V55F_WINDOWS_SINGLE_AUTUPDATE_JOB_CLEANUP",
    "Windows 8 compatible TLS bootstrap",
    '[ValidateSet("auto","scalar","avx2","avx512","cuda")]',
    "'^-cuda$'",
    '("scalar","avx2","avx512","cuda")',
    "coded-miner-cuda.exe is not included",
    "$sec = 60",
    '$currentKey = "$CurrentChannel`:$CurrentCommit`:$CurrentVersion"',
    '$targetKey = "$targetChannel`:$targetCommit`:$targetVersion"',
    "if ($targetKey -eq $currentKey)",
    "action=stop_miner",
    "-ReleaseChannel",
    "-ReleaseCommit",
    "-ReleaseVersion",
)

for marker in required:
    if marker not in source:
        raise SystemExit(
            f"ERROR: missing marker: {marker}"
        )

for forbidden in (
    "M1091V63G2A3_VALIDATED_INSTALL_CACHE",
    "M1091V63G2A3_IDEMPOTENT_VALIDATED_INSTALL",
    "installed-fingerprint.json",
    "staging-",
):
    if forbidden in source:
        raise SystemExit(
            f"ERROR: incompatible rewrite remains: {forbidden}"
        )

# Windows PowerShell 3 does not accept a new line followed by
# .Method() as used by the reverted G2A3C implementation.
bad_member_lines = re.findall(
    r"(?m)^[ \t]+\.[A-Za-z_][A-Za-z0-9_]*\(",
    source,
)

if bad_member_lines:
    raise SystemExit(
        "ERROR: Windows-8-incompatible multiline member calls: "
        + repr(bad_member_lines)
    )

if source.count(
    "$sec = 60"
) != 2:
    raise SystemExit(
        "ERROR: expected two existing one-minute defaults"
    )

if source.count(
    "Start-CodedWindowsChannelAutoupdateV53B -Root"
) != 1:
    raise SystemExit(
        "ERROR: active channel watcher count is not one"
    )

if source.count(
    "release_channel = $releaseChannelValue"
) != 7:
    raise SystemExit(
        "ERROR: release channel missing from raw/six payloads"
    )

if source.count(
    "release_commit = $releaseCommitValue"
) != 7:
    raise SystemExit(
        "ERROR: release commit missing from raw/six payloads"
    )

if source.count(
    "release_version = $releaseVersionValue"
) != 7:
    raise SystemExit(
        "ERROR: release version missing from raw/six payloads"
    )

watch_start = source.find(
    "function Start-CodedWindowsChannelAutoupdateV53B {"
)

watch_end = source.find(
    "\n}\n\n\n\nRemove-Item $dir",
    watch_start,
)

if watch_start < 0 or watch_end < 0:
    raise SystemExit(
        "ERROR: watcher boundaries missing"
    )

watcher = source[
    watch_start:
    watch_end
]

for forbidden in (
    "Download-File",
    "Expand-TarGz",
    "Remove-Item $dir",
):
    if forbidden in watcher:
        raise SystemExit(
            "ERROR: minute watcher performs installation work: "
            + forbidden
        )

same_target = watcher.find(
    "if ($targetKey -eq $currentKey)"
)

stop_miner = watcher.find(
    "Stop-Process"
)

if (
    same_target < 0 or
    stop_miner < 0 or
    same_target > stop_miner
):
    raise SystemExit(
        "ERROR: unchanged-target guard is not before miner stop"
    )

if re.search(
    r"Register-ScheduledTask|New-ScheduledTask|schtasks",
    source,
    re.IGNORECASE,
):
    raise SystemExit(
        "ERROR: unexpected Windows scheduled task"
    )

print(
    "M1091V63G2A3E_WINDOWS8_SAFE_UPDATE_TEST_OK"
)
