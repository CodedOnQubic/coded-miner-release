#!/usr/bin/env python3

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]

runner_path = ROOT / "run.ps1"

if not runner_path.is_file():
    raise SystemExit(
        f"ERROR: missing runner: {runner_path}"
    )

runner = runner_path.read_text(
    encoding="utf-8",
)

required = (
    "M1091V63G2A3_WINDOWS_CHANNEL_IDENTITY_AND_IDEMPOTENT_UPDATE",
    "M1091V63G2A3_WINDOWS_RELEASE_IDENTITY_IN_ALL_ANALYTICS",
    "M1091V63G2A3_BETA_FAIL_CLOSED_ON_STATUS_OUTAGE",
    "M1091V63G2A3_BETA_WATCHER_FAIL_CLOSED",
    "M1091V63G2A3_PERSIST_DESIRED_CHANNEL",
    "M1091V63G2A3_VALIDATED_INSTALL_CACHE",
    "M1091V63G2A3_LIGHTWEIGHT_15_MINUTE_CHECK",
    "M1091V63G2A3_IDEMPOTENT_VALIDATED_INSTALL",
    'desired-channel.txt',
    'resolved-channel.txt',
    'installed-fingerprint.json',
    'asset_sha256',
    'Get-CodedFileSha256V63G2A3',
    'Downloaded manifest commit mismatch',
    'Downloaded manifest version mismatch',
    '$CurrentChannel`:$CurrentCommit`:$CurrentVersion',
    '$targetChannel`:$targetCommit`:$targetVersion',
    '-ReleaseChannel',
    '-ReleaseCommit',
    '-ReleaseVersion',
    'release_channel = $releaseChannelValue',
    'release_commit = $releaseCommitValue',
    'release_version = $releaseVersionValue',
)

for marker in required:
    if marker not in runner:
        raise SystemExit(
            f"ERROR: missing marker: {marker}"
        )

for forbidden in (
    "$sec = 60",
    "if ($parsed -ge 30)",
    'Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue\nNew-Item -ItemType Directory -Force $dir',
):
    if forbidden in runner:
        raise SystemExit(
            f"ERROR: forbidden legacy logic remains: {forbidden}"
        )

if runner.count(
    "$sec = 900"
) != 2:
    raise SystemExit(
        "ERROR: expected two 900-second updater defaults"
    )

if runner.count(
    "release_commit = $releaseCommitValue"
) != 7:
    raise SystemExit(
        "ERROR: release commit is not present in raw plus six payloads"
    )

if runner.count(
    "release_version = $releaseVersionValue"
) != 7:
    raise SystemExit(
        "ERROR: release version is not present in raw plus six payloads"
    )

if runner.count(
    "release_channel = $releaseChannelValue"
) != 7:
    raise SystemExit(
        "ERROR: release channel is not present in raw plus six payloads"
    )

if runner.count(
    "Start-CodedWindowsChannelAutoupdateV53B -Root"
) != 1:
    raise SystemExit(
        "ERROR: active channel updater invocation count is not one"
    )

if re.search(
    r"Register-ScheduledTask|New-ScheduledTask|schtasks",
    runner,
    re.IGNORECASE,
):
    raise SystemExit(
        "ERROR: OS scheduled task was added unexpectedly"
    )

# Contract model:
# latest never selects beta;
# beta selects beta while active;
# beta selects public after explicit beta disable;
# beta status outage produces no channel switch.
def select(
    want_beta: bool,
    status_ok: bool,
    beta_active: bool,
    public_available: bool,
):
    if status_ok:
        if want_beta and beta_active:
            return "beta"

        if public_available:
            return "latest"

        return None

    if want_beta:
        return None

    return "latest"


assert select(
    False,
    True,
    True,
    True,
) == "latest"

assert select(
    True,
    True,
    True,
    True,
) == "beta"

assert select(
    True,
    True,
    False,
    True,
) == "latest"

assert select(
    True,
    False,
    False,
    True,
) is None

print(
    "M1091V63G2A3_WINDOWS_CHANNEL_UPDATE_TEST_OK"
)
