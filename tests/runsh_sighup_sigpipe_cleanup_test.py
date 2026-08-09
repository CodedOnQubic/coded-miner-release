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

RUN_SH = ROOT / "run.sh"


text = RUN_SH.read_text(
    encoding="utf-8",
)

lines = text.splitlines()


start = next(
    i
    for i, line in enumerate(lines)
    if line == "coded_m1091v55f_cleanup_children() {"
)

end = next(
    i
    for i in range(
        start + 1,
        len(lines),
    )
    if lines[i] == "}"
)


cleanup = lines[
    start:end + 1
]


restore_positions = [
    i
    for i, line in enumerate(cleanup)
    if "exec 2>&3 3>&-" in line
]


assert len(
    restore_positions
) == 1


restore = restore_positions[0]


debug = next(
    i
    for i, line in enumerate(cleanup)
    if "coded_m1091v54k_debug" in line
)


first_stop = next(
    i
    for i, line in enumerate(cleanup)
    if "coded_m1091v55f_stop_child" in line
)


filter_guard = next(
    i
    for i, line in enumerate(cleanup)
    if (
        "coded_m1091v55f_valid_pid"
        in line
        and
        "CODED_V55E_STDERR_FILTER_PID"
        in line
    )
)


assert restore < debug
assert restore < first_stop
assert restore < filter_guard


assert (
    "\n".join(cleanup).count(
        "exec 2>&3 3>&-"
    )
    == 1
)


#
# Worst-case deterministic SIGHUP ordering:
# the direct awk filter dies before Bash begins its HUP cleanup.
# FD2 must therefore be detached from the broken filter pipe
# before any cleanup output.
#
HARNESS = r'''#!/usr/bin/env bash
set -u

exec 3>&2

exec 2> >(
  exec awk '
    { print > "/dev/fd/3"; fflush("/dev/fd/3") }
  '
)

FILTER_PID="$!"

printf '%s\n' "$$" > "$RUNNER_FILE"
printf '%s\n' "$FILTER_PID" > "$FILTER_FILE"

on_hup() {
  trap - HUP

  if { : >&3; } 2>/dev/null; then
    exec 2>&3 3>&-
  fi

  printf '%s\n' \
    "POST_RESTORE_CLEANUP_OUTPUT" \
    >&2

  exit 129
}

trap on_hup HUP

while :
do
  sleep 1
done
'''


with tempfile.TemporaryDirectory() as raw:

    root = Path(raw)

    script = root / "harness.sh"
    runner_file = root / "runner.pid"
    filter_file = root / "filter.pid"

    script.write_text(
        HARNESS,
        encoding="utf-8",
    )

    script.chmod(
        0o755
    )


    env = os.environ.copy()

    env[
        "RUNNER_FILE"
    ] = str(
        runner_file
    )

    env[
        "FILTER_FILE"
    ] = str(
        filter_file
    )


    proc = subprocess.Popen(
        [
            "/bin/bash",
            str(script),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
        start_new_session=True,
    )


    deadline = (
        time.monotonic()
        + 5
    )


    while (
        time.monotonic()
        < deadline
    ):

        if (
            runner_file.exists()
            and
            filter_file.exists()
        ):
            break

        if proc.poll() is not None:
            raise AssertionError(
                (
                    "harness exited early",
                    proc.returncode,
                )
            )

        time.sleep(
            0.02
        )


    assert runner_file.exists()
    assert filter_file.exists()


    runner_pid = int(
        runner_file.read_text().strip()
    )

    filter_pid = int(
        filter_file.read_text().strip()
    )


    os.kill(
        filter_pid,
        signal.SIGHUP,
    )


    time.sleep(
        0.10
    )


    os.kill(
        runner_pid,
        signal.SIGHUP,
    )


    try:

        stdout, stderr = proc.communicate(
            timeout=5
        )

    except subprocess.TimeoutExpired:

        os.killpg(
            runner_pid,
            signal.SIGKILL,
        )

        stdout, stderr = proc.communicate()

        raise AssertionError(
            "SIGHUP regression timed out"
        )


    assert proc.returncode == 129, (
        proc.returncode,
        stdout,
        stderr,
    )


    assert (
        "POST_RESTORE_CLEANUP_OUTPUT"
        in stderr
    )


print(
    "stderr_restore_count=1"
)

print(
    "stderr_restore_before_debug=true"
)

print(
    "stderr_restore_before_first_child_stop=true"
)

print(
    "stderr_restore_before_filter_handling=true"
)

print(
    "dead_filter_sighup_exit_code=129"
)

print(
    "dead_filter_sighup_sigpipe=false"
)

print(
    "runsh_sighup_sigpipe_cleanup_test=GREEN"
)
