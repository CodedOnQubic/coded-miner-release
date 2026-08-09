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


BEGIN = (
    "# M1091V55F_PUBLIC_SIGNAL_TREE_CLEANUP_BEGIN"
)

END = (
    "# M1091V55F_PUBLIC_SIGNAL_TREE_CLEANUP_END"
)


start = source.index(
    BEGIN
)

end = (
    source.index(
        END,
        start,
    )
    + len(END)
)

block = source[
    start:end
]


for required in (
    "coded_m1091v55f_stop_child",
    "coded_m1091v55f_cleanup_children",
    "coded_m1091v55f_signal_exit",
    "coded_m1091v55f_exit_cleanup",
    "coded_m1091v55f_install_signal_traps",
):
    assert required in block


assert (
    'wait "$MINER_PID" 2>/dev/null || true'
    not in source
)

assert (
    'wait "$ANALYTICS_PID" 2>/dev/null || true'
    not in source
)

assert (
    'RESTART_WATCH_PID="$!"'
    in source
)

assert (
    'coded_m1091v55f_cleanup_children "console_exit"'
    in source
)


def alive(pid):

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
    pid,
    timeout=5.0,
):

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


def run_case(
    label,
    sig,
    expected_rc,
):

    with tempfile.TemporaryDirectory() as raw:

        root = Path(raw)

        pid_dir = (
            root / "pids"
        )

        pid_dir.mkdir()

        ready = (
            root / "ready"
        )

        child_file = (
            root / "children"
        )

        harness = (
            root / "harness.sh"
        )

        body = (
            "#!/usr/bin/env bash\n"
            "set -u\n\n"
            "coded_m1091v54k_debug() { :; }\n\n"
            + block
            + "\n\n"
            + 'PID_DIR="'
            + str(pid_dir)
            + '"\n'
            + 'sleep 300 & MINER_PID="$!"\n'
            + 'echo "$MINER_PID" > "$PID_DIR/miner.pid"\n'
            + 'sleep 300 & ANALYTICS_PID="$!"\n'
            + 'echo "$ANALYTICS_PID" > "$PID_DIR/analytics.pid"\n'
            + 'sleep 300 & CONSOLE_PID="$!"\n'
            + 'sleep 300 & UPDATE_PID="$!"\n'
            + 'echo "$UPDATE_PID" > "$PID_DIR/autoupdate.pid"\n'
            + 'sleep 300 & RESTART_WATCH_PID="$!"\n'
            + 'echo "$RESTART_WATCH_PID" > "$PID_DIR/restart-watch.pid"\n'
            + 'printf "%s\\n" '
            + '"$MINER_PID" '
            + '"$ANALYTICS_PID" '
            + '"$CONSOLE_PID" '
            + '"$UPDATE_PID" '
            + '"$RESTART_WATCH_PID" '
            + '> "'
            + str(child_file)
            + '"\n'
            + "coded_m1091v55f_install_signal_traps\n"
            + ': > "'
            + str(ready)
            + '"\n'
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


        children = [
            int(x)
            for x in (
                child_file
                .read_text()
                .splitlines()
            )
            if x.strip()
        ]

        assert len(children) == 5


        for pid in children:
            assert alive(pid), (
                label,
                "child_not_alive_before_test",
                pid,
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


        for pid in children:

            assert wait_dead(
                pid
            ), (
                label,
                "orphan_child",
                pid,
            )


        for name in (
            "miner.pid",
            "analytics.pid",
            "autoupdate.pid",
            "restart-watch.pid",
        ):

            assert not (
                pid_dir / name
            ).exists(), (
                label,
                "stale_pid_file",
                name,
            )


        print(
            "runsh_"
            + label
            + "_exit_code="
            + str(proc.returncode)
        )

        print(
            "runsh_"
            + label
            + "_children_dead=true"
        )

        print(
            "runsh_"
            + label
            + "_pid_files_clean=true"
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
    "runsh_ctrl_c_cleanup_green=true"
)

print(
    "runsh_terminal_close_cleanup_green=true"
)

print(
    "runsh_sigterm_cleanup_green=true"
)

print(
    "runsh_normal_exit_cleanup_green=true"
)

print(
    "runsh_signal_cleanup_test=GREEN"
)
