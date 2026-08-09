#!/usr/bin/env python3

from __future__ import annotations

import os
import re
import signal
import subprocess
import tempfile
import time

from pathlib import Path


ROOT = Path(
    __file__
).resolve().parents[1]

RUNSH = ROOT / "run.sh"

source = RUNSH.read_text(
    encoding="utf-8",
)


BEGIN = (
    "# M1091V55F_PUBLIC_SIGNAL_TREE_CLEANUP_BEGIN"
)

END = (
    "# M1091V55F_PUBLIC_SIGNAL_TREE_CLEANUP_END"
)


start = source.index(
    BEGIN
)

finish = (
    source.index(
        END,
        start,
    )
    + len(END)
)


block = source[
    start:finish
]


for marker in (
    "coded_m1091v55f_stop_child_single",
    "coded_m1091v55f_stop_descendants",
    "coded_m1091v55f_capture_process_group_baseline",
    "coded_m1091v55f_sweep_owned_process_group",
):

    assert marker in block, marker


def alive(pid: int) -> bool:

    try:

        os.kill(
            pid,
            0,
        )

    except ProcessLookupError:

        return False

    except PermissionError:

        return True

    return True


def ps_rows():

    completed = subprocess.run(
        [
            "ps",
            "-axo",
            "pid=,ppid=,pgid=,stat=,comm=",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )

    rows = []

    for line in completed.stdout.splitlines():

        match = re.match(
            r"^\s*"
            r"(\d+)\s+"
            r"(\d+)\s+"
            r"(\d+)\s+"
            r"(\S+)\s+"
            r"(\S+)",
            line,
        )

        if not match:
            continue

        rows.append({
            "pid":
                int(
                    match.group(1)
                ),

            "ppid":
                int(
                    match.group(2)
                ),

            "pgid":
                int(
                    match.group(3)
                ),

            "stat":
                match.group(4),

            "comm":
                match.group(5),
        })

    return rows


def group_members(
    pgid: int,
):

    return [
        row
        for row in ps_rows()
        if row["pgid"] == pgid
    ]


def wait_dead(
    pids,
    timeout=10.0,
):

    deadline = (
        time.monotonic()
        + timeout
    )

    values = set(
        pids
    )


    while (
        time.monotonic()
        < deadline
    ):

        living = {
            pid
            for pid in values
            if alive(
                pid
            )
        }

        if not living:

            return True

        time.sleep(
            0.05
        )


    return not any(
        alive(
            pid
        )
        for pid in values
    )


def wait_group_empty(
    pgid: int,
    timeout=12.0,
):

    deadline = (
        time.monotonic()
        + timeout
    )


    while (
        time.monotonic()
        < deadline
    ):

        if not group_members(
            pgid
        ):

            return True

        time.sleep(
            0.05
        )


    return not group_members(
        pgid
    )


def force_kill_pid(
    pid,
):

    if not pid:

        return

    try:

        os.kill(
            pid,
            signal.SIGKILL,
        )

    except ProcessLookupError:

        pass


def force_kill_group(
    pgid,
):

    if not pgid:

        return

    try:

        os.killpg(
            pgid,
            signal.SIGKILL,
        )

    except ProcessLookupError:

        pass


def make_harness(
    root: Path,
    *,
    baseline: bool,
):

    ready = root / "ready"
    helper_file = root / "helper.pid"
    child_file = root / "child.pid"
    baseline_file = root / "baseline.pid"

    harness = root / "harness.sh"


    baseline_code = ""


    if baseline:

        baseline_code = f'''
sleep 300 >/dev/null 2>&1 &
BASELINE_PID="$!"
printf "%s\\n" "$BASELINE_PID" > "{baseline_file}"
'''


    harness.write_text(
        "#!/usr/bin/env bash\n"
        "set -u\n"
        "\n"
        "coded_m1091v54k_debug() { :; }\n"
        "\n"
        + block
        + "\n"
        + baseline_code
        + """
unset CODED_V55F_RUNNER_PGID || true
unset CODED_V55F_PGID_BASELINE_PIDS || true
unset CODED_V55F_PGID_BASELINE_CAPTURED || true

CODED_V55E_STDERR_FILTER_PID=""
MINER_PID=""
ANALYTICS_PID=""
CONSOLE_PID=""
RESTART_WATCH_PID=""
UPDATE_PID=""

coded_m1091v55f_install_signal_traps
"""
        + f'''
CHILD_FILE="{child_file}" \
/bin/bash -c '
  trap "" INT HUP TERM

  sleep 300 >/dev/null 2>&1 &
  child="$!"

  printf "%s\\n" "$child" > "$CHILD_FILE"

  wait "$child"
' >/dev/null 2>&1 &

UPDATE_PID="$!"

printf "%s\\n" "$UPDATE_PID" > "{helper_file}"

while [ ! -s "{child_file}" ]
do
  sleep 0.05
done

: > "{ready}"

while :
do
  sleep 1 >/dev/null 2>&1
done
''',
        encoding="utf-8",
    )


    harness.chmod(
        0o755
    )


    return (
        harness,
        ready,
        helper_file,
        child_file,
        baseline_file,
    )


def wait_ready(
    proc,
    ready: Path,
):

    deadline = (
        time.monotonic()
        + 8.0
    )


    while (
        time.monotonic()
        < deadline
    ):

        if ready.exists():

            return

        if proc.poll() is not None:

            raise AssertionError(
                (
                    "harness exited before ready",
                    proc.returncode,
                )
            )

        time.sleep(
            0.05
        )


    raise AssertionError(
        "harness readiness timeout"
    )


def runner_only_term_case():

    with tempfile.TemporaryDirectory() as raw:

        root = Path(raw)


        (
            harness,
            ready,
            helper_file,
            child_file,
            baseline_file,
        ) = make_harness(
            root,
            baseline=True,
        )


        proc = subprocess.Popen(
            [
                "/bin/bash",
                str(harness),
            ],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )


        pgid = proc.pid

        baseline_pid = None


        try:

            wait_ready(
                proc,
                ready,
            )


            helper_pid = int(
                helper_file
                .read_text()
                .strip()
            )

            child_pid = int(
                child_file
                .read_text()
                .strip()
            )

            baseline_pid = int(
                baseline_file
                .read_text()
                .strip()
            )


            assert alive(
                helper_pid
            )

            assert alive(
                child_pid
            )

            assert alive(
                baseline_pid
            )


            members = group_members(
                pgid
            )


            assert any(
                row["pid"]
                == helper_pid
                for row in members
            )

            assert any(
                row["pid"]
                == child_pid
                for row in members
            )

            assert any(
                row["pid"]
                == baseline_pid
                for row in members
            )


            os.kill(
                proc.pid,
                signal.SIGTERM,
            )


            rc = proc.wait(
                timeout=20,
            )


            assert rc == 143, rc


            assert wait_dead(
                {
                    helper_pid,
                    child_pid,
                }
            ), (
                helper_pid,
                child_pid,
                group_members(
                    pgid
                ),
            )


            assert alive(
                baseline_pid
            )


            print(
                "runner_only_term_exit_code=143"
            )

            print(
                "runner_only_term_owned_process_count=2"
            )

            print(
                "runner_only_term_tracked_helper_dead=true"
            )

            print(
                "runner_only_term_descendant_sleep_dead=true"
            )

            print(
                "runner_only_term_baseline_preserved=true"
            )


        finally:

            force_kill_pid(
                baseline_pid
            )

            if proc.poll() is None:

                force_kill_pid(
                    proc.pid
                )


def foreground_group_sigint_case():

    with tempfile.TemporaryDirectory() as raw:

        root = Path(raw)


        (
            harness,
            ready,
            helper_file,
            child_file,
            _,
        ) = make_harness(
            root,
            baseline=False,
        )


        proc = subprocess.Popen(
            [
                "/bin/bash",
                str(harness),
            ],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )


        pgid = proc.pid


        try:

            wait_ready(
                proc,
                ready,
            )


            helper_pid = int(
                helper_file
                .read_text()
                .strip()
            )

            child_pid = int(
                child_file
                .read_text()
                .strip()
            )


            assert alive(
                helper_pid
            )

            assert alive(
                child_pid
            )


            before = group_members(
                pgid
            )


            assert len(
                before
            ) >= 3, before


            os.killpg(
                pgid,
                signal.SIGINT,
            )


            rc = proc.wait(
                timeout=20,
            )


            assert rc == 130, rc


            assert wait_group_empty(
                pgid,
                timeout=12,
            ), group_members(
                pgid
            )


            assert not alive(
                helper_pid
            )

            assert not alive(
                child_pid
            )


            print(
                "foreground_group_sigint_exit_code=130"
            )

            print(
                "foreground_group_sigint_tracked_helper_dead=true"
            )

            print(
                "foreground_group_sigint_descendant_sleep_dead=true"
            )

            print(
                "foreground_group_sigint_process_group_empty=true"
            )


        finally:

            if group_members(
                pgid
            ):

                force_kill_group(
                    pgid
                )


runner_only_term_case()
foreground_group_sigint_case()


print(
    "recursive_descendant_cleanup_green=true"
)

print(
    "process_group_baseline_protection_green=true"
)

print(
    "residual_process_group_cleanup_green=true"
)

print(
    "runsh_descendant_residual_cleanup_test=GREEN"
)
