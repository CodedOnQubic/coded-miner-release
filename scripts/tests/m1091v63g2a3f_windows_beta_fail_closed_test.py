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
    "M1091V63G2A3F_WINDOWS_BETA_STATUS_FAIL_CLOSED",
    "M1091V63G2A3F_OUTER_BETA_FAIL_CLOSED",
    "M1091V63G2A3F_WATCHER_BETA_FAIL_CLOSED",
    "M1091V63G2A3F_CACHED_BETA_STARTUP_FALLBACK",
    "Beta channel-status unavailable and no cached Beta installation exists.",
    "Beta status temporarily unavailable;",
    'if ($BetaRequested) {',
    'if ($WantBeta) {',
    '$sec = 60',
    '$currentKey = "$CurrentChannel`:$CurrentCommit`:$CurrentVersion"',
    '$targetKey = "$targetChannel`:$targetCommit`:$targetVersion"',
    "if ($targetKey -eq $currentKey)",
    "action=stop_miner",
)

for marker in required:
    if marker not in runner:
        raise SystemExit(
            f"ERROR: missing marker: {marker}"
        )

if runner.count(
    "$sec = 60"
) != 2:
    raise SystemExit(
        "ERROR: one-minute check defaults changed"
    )

if runner.count(
    "Start-CodedWindowsChannelAutoupdateV53B -Root"
) != 1:
    raise SystemExit(
        "ERROR: active channel watcher count is not one"
    )

outer_start = runner.find(
    "function Get-CodedWindowsReleaseSelectionV53B {"
)

outer_end = runner.find(
    "\n}\n\n$root = Join-Path",
    outer_start,
)

if outer_start < 0 or outer_end < 0:
    raise SystemExit(
        "ERROR: outer selection boundaries missing"
    )

outer = runner[
    outer_start:
    outer_end
]

outer_fail_closed = outer.find(
    "M1091V63G2A3F_OUTER_BETA_FAIL_CLOSED"
)

outer_github = outer.find(
    "https://api.github.com/repos/"
)

if (
    outer_fail_closed < 0 or
    outer_github < 0 or
    outer_fail_closed > outer_github
):
    raise SystemExit(
        "ERROR: outer Beta fail-closed guard "
        "is not before GitHub latest fallback"
    )

watch_start = runner.find(
    "function Start-CodedWindowsChannelAutoupdateV53B {"
)

watch_end = runner.find(
    "\n}\n\n\n\nRemove-Item $dir",
    watch_start,
)

if watch_start < 0 or watch_end < 0:
    raise SystemExit(
        "ERROR: watcher boundaries missing"
    )

watcher = runner[
    watch_start:
    watch_end
]

watch_fail_closed = watcher.find(
    "M1091V63G2A3F_WATCHER_BETA_FAIL_CLOSED"
)

watch_github = watcher.find(
    "https://api.github.com/repos/"
)

if (
    watch_fail_closed < 0 or
    watch_github < 0 or
    watch_fail_closed > watch_github
):
    raise SystemExit(
        "ERROR: watcher Beta fail-closed guard "
        "is not before GitHub latest fallback"
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

bad_member_lines = re.findall(
    r"(?m)^[ \t]+\.[A-Za-z_][A-Za-z0-9_]*\(",
    runner,
)

if bad_member_lines:
    raise SystemExit(
        "ERROR: Windows-8-incompatible member syntax: "
        + repr(bad_member_lines)
    )

if re.search(
    r"Register-ScheduledTask|New-ScheduledTask|schtasks",
    runner,
    re.IGNORECASE,
):
    raise SystemExit(
        "ERROR: unexpected Scheduled Task logic"
    )

# Required decision behavior.
def resolve(
    beta_requested: bool,
    status_success: bool,
    beta_active: bool,
    public_available: bool,
):
    if status_success:
        if beta_requested and beta_active:
            return "beta"

        if public_available:
            return "latest"

        return None

    if beta_requested:
        return None

    return "latest"


assert resolve(
    True,
    True,
    True,
    True,
) == "beta"

assert resolve(
    True,
    True,
    False,
    True,
) == "latest"

assert resolve(
    True,
    False,
    False,
    True,
) is None

assert resolve(
    False,
    False,
    False,
    True,
) == "latest"

print(
    "M1091V63G2A3F_WINDOWS_BETA_FAIL_CLOSED_TEST_OK"
)
