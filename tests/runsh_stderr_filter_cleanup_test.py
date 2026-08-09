#!/usr/bin/env python3

from __future__ import annotations

import os
import signal
import subprocess
import tempfile
import time

from pathlib import Path


ROOT = Path(
    __file__
).resolve().parents[1]

RUNSH = ROOT / "run.sh"

source = RUNSH.read_text()


FILTER_START = (
    "coded_m1091v55e_install_public_stderr_filter() {\n"
)

FILTER_END = (
    "\ncoded_m1091v55e_stop_console_quiet() {\n"
)


start = source.index(
    FILTER_START
)

end = source.index(
    FILTER_END,
    start,
)

filter_function = source[
    start:end
]


BEGIN = (
    "# M1091V55F_PUBLIC_SIGNAL_TREE_CLEANUP_BEGIN"
)

END = (
    "# M1091V55F_PUBLIC_SIGNAL_TREE_CLEANUP_END"
)


block_start = source.index(
    BEGIN
)

block_end = (
    source.index(
        END,
        block_start,
    )
    + len(END)
)

cleanup_block = source[
    block_start:block_end
]


assert (
    "exec 2> >(exec awk '"
    in filter_function
)

assert (
    'CODED_V55E_STDERR_FILTER_PID="$!"'
    in filter_function
)

assert (
    "export CODED_V55E_STDERR_FILTER_PID"
    in filter_function
)

assert (
    '"stderr-filter"'
    in cleanup_block
)

assert (
    "unset CODED_V55E_STDERR_FILTERED"
    in cleanup_block
)


def alive(
    pid: int,
) -> bool:

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


def wait_dead(
    pid: int,
    timeout: float = 5.0,
) -> bool:

    deadline = (
        time.monotonic()
        + timeout
    )

    while (
        time.monotonic()
        < deadline
    ):

        if not alive(pid):
            return True

        time.sleep(
            0.05
        )

    return not alive(pid)


def comm(
    pid: int,
) -> str:

    result = subprocess.run(
        [
            "ps",
            "-p",
            str(pid),
            "-o",
            "comm=",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )

    return (
        result.stdout
        .strip()
    )


def run_case(
    label: str,
    sig: int | None,
    expected_rc: int,
) -> None:

    with tempfile.TemporaryDirectory() as raw:

        root = Path(raw)

        pid_dir = (
            root / "pids"
        )

        pid_dir.mkdir()

        ready = (
            root / "ready"
        )

        filter_pid_file = (
            root / "filter.pid"
        )

        harness = (
            root / "harness.sh"
        )


        body = (
            "#!/usr/bin/env bash\n"
            "set -u\n"
            "CODED_PUBLIC_DEBUG=0\n"
            "unset CODED_V55E_STDERR_FILTERED\n"
            "unset CODED_V55E_STDERR_FILTER_PID\n"
            "\n"
            "coded_m1091v54k_debug() { :; }\n"
            "\n"
            + filter_function
            + "\n"
            + cleanup_block
            + "\n\n"
            + f'PID_DIR="{pid_dir}"\n'
            + "coded_m1091v55e_install_public_stderr_filter\n"
            + f'echo "$CODED_V55E_STDERR_FILTER_PID" > "{filter_pid_file}"\n'
            + 'sleep 300 & MINER_PID="$!"\n'
            + 'echo "$MINER_PID" > "$PID_DIR/miner.pid"\n'
            + 'sleep 300 & ANALYTICS_PID="$!"\n'
            + 'echo "$ANALYTICS_PID" > "$PID_DIR/analytics.pid"\n'
            + 'CONSOLE_PID=""\n'
            + 'UPDATE_PID=""\n'
            + 'RESTART_WATCH_PID=""\n'
            + "coded_m1091v55f_install_signal_traps\n"
            + 'echo "filter_test_stderr" >&2\n'
            + f': > "{ready}"\n'
        )


        if sig is None:

            body += (
                "sleep 0.30\n"
                "exit 0\n"
            )

        else:

            body += (
                "while :; do "
                "sleep 1; "
                "done\n"
            )


        harness.write_text(
            body
        )

        harness.chmod(
            0o755
        )


        proc = subprocess.Popen(
            [
                "/bin/bash",
                str(harness),
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            start_new_session=True,
        )


        deadline = (
            time.monotonic()
            + 5.0
        )


        while (
            time.monotonic()
            < deadline
            and not ready.exists()
        ):

            if proc.poll() is not None:
                break

            time.sleep(
                0.05
            )


        if not ready.exists():

            out, err = proc.communicate(
                timeout=5
            )

            raise AssertionError(
                (
                    label,
                    "harness_not_ready",
                    proc.returncode,
                    out,
                    err,
                )
            )


        filter_pid = int(
            filter_pid_file
            .read_text()
            .strip()
        )


        assert alive(
            filter_pid
        ), (
            label,
            "filter_not_alive",
            filter_pid,
        )


        filter_comm = (
            Path(
                comm(filter_pid)
            )
            .name
            .lower()
        )


        assert (
            "awk"
            in filter_comm
        ), (
            label,
            "filter_is_not_direct_awk",
            filter_pid,
            filter_comm,
        )


        print(
            "stderr_filter_"
            + label
            + "_direct_awk=true"
        )


        if sig is not None:

            os.kill(
                proc.pid,
                sig,
            )


        out, err = proc.communicate(
            timeout=15
        )


        assert (
            proc.returncode
            == expected_rc
        ), (
            label,
            proc.returncode,
            expected_rc,
            out,
            err,
        )


        assert wait_dead(
            filter_pid
        ), (
            label,
            "stderr_filter_orphan",
            filter_pid,
        )


        print(
            "stderr_filter_"
            + label
            + "_exit_code="
            + str(proc.returncode)
        )

        print(
            "stderr_filter_"
            + label
            + "_dead=true"
        )


run_case(
    "sigint",
    signal.SIGINT,
    130,
)

run_case(
    "sighup",
    signal.SIGHUP,
    129,
)

run_case(
    "sigterm",
    signal.SIGTERM,
    143,
)

run_case(
    "normal_exit",
    None,
    0,
)


print(
    "stderr_filter_pid_owned=true"
)

print(
    "stderr_filter_bash_wrapper_eliminated=true"
)

print(
    "stderr_filter_ctrl_c_cleanup_green=true"
)

print(
    "stderr_filter_terminal_close_cleanup_green=true"
)

print(
    "stderr_filter_sigterm_cleanup_green=true"
)

print(
    "stderr_filter_normal_exit_cleanup_green=true"
)

print(
    "runsh_stderr_filter_cleanup_test=GREEN"
)
