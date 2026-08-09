#!/usr/bin/env python3

from __future__ import annotations

import os
import signal
import subprocess
import tempfile
import time

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUN_SH = ROOT / "run.sh"

source = RUN_SH.read_text(
    encoding="utf-8",
)

new_install = (
    "exec 2> >(trap '' HUP; exec awk '"
)

old_install = (
    "exec 2> >(exec awk '"
)

assert source.count(new_install) == 1
assert source.count(old_install) == 0

assert (
    'CODED_V55E_STDERR_FILTER_PID="$!"'
    in source
)

assert (
    "export CODED_V55E_STDERR_FILTER_PID"
    in source
)


function_start = source.index(
    "coded_m1091v55e_install_public_stderr_filter() {"
)

function_end = source.index(
    "\ncoded_m1091v55e_install_public_stderr_filter\n",
    function_start + 1,
)

filter_function = source[
    function_start:function_end
]

assert "trap '' HUP; exec awk" in filter_function
assert "bash -c" not in filter_function


HARNESS = r'''#!/usr/bin/env bash
set -u

exec 3>&2

exec 2> >(
  trap '' HUP
  exec awk '
    { print > "/dev/fd/3"; fflush("/dev/fd/3") }
  '
)

FILTER_PID="$!"

printf '%s\n' "$$" > "$RUNNER_FILE"
printf '%s\n' "$FILTER_PID" > "$FILTER_FILE"

on_hup() {
  trap - HUP INT TERM EXIT

  if { : >&3; } 2>/dev/null; then
    exec 2>&3 3>&-
  fi

  for _ in 1 2 3 4 5 6 7 8 9 10
  do
    if ! kill -0 "$FILTER_PID" 2>/dev/null; then
      break
    fi

    sleep 0.02
  done

  if kill -0 "$FILTER_PID" 2>/dev/null; then
    kill -TERM "$FILTER_PID" 2>/dev/null || true
  fi

  wait "$FILTER_PID" 2>/dev/null || true

  printf '%s\n' \
    "R33_HUP_CLEANUP_REACHED" \
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

    tmp = Path(raw)

    script = tmp / "harness.sh"
    runner_file = tmp / "runner.pid"
    filter_file = tmp / "filter.pid"

    script.write_text(
        HARNESS,
        encoding="utf-8",
    )

    script.chmod(0o755)

    env = os.environ.copy()

    env["RUNNER_FILE"] = str(runner_file)
    env["FILTER_FILE"] = str(filter_file)

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

    deadline = time.monotonic() + 5

    while time.monotonic() < deadline:

        if (
            runner_file.exists()
            and
            filter_file.exists()
        ):
            break

        if proc.poll() is not None:
            raise AssertionError(
                (
                    "runner exited early",
                    proc.returncode,
                )
            )

        time.sleep(0.02)

    assert runner_file.exists()
    assert filter_file.exists()

    runner_pid = int(
        runner_file.read_text().strip()
    )

    filter_pid = int(
        filter_file.read_text().strip()
    )


    deadline = time.monotonic() + 3
    comm = ""

    while time.monotonic() < deadline:

        ps = subprocess.run(
            [
                "ps",
                "-o",
                "comm=",
                "-p",
                str(filter_pid),
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            check=False,
        )

        comm = Path(
            ps.stdout.strip()
        ).name

        if comm == "awk":
            break

        time.sleep(0.02)

    assert comm == "awk", comm


    os.kill(
        filter_pid,
        signal.SIGHUP,
    )

    time.sleep(0.15)

    try:
        os.kill(filter_pid, 0)
        survived_direct_hup = True
    except ProcessLookupError:
        survived_direct_hup = False

    assert survived_direct_hup


    os.killpg(
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
            "R3.3 group HUP timeout"
        )


    assert proc.returncode == 129, (
        proc.returncode,
        stdout,
        stderr,
    )

    assert (
        "R33_HUP_CLEANUP_REACHED"
        in stderr
    )


    try:
        os.kill(filter_pid, 0)
        filter_dead = False
    except ProcessLookupError:
        filter_dead = True

    assert filter_dead


print("r33_source_hup_ignore_present=true")
print("r33_filter_direct_awk=true")
print("r33_filter_survives_direct_sighup=true")
print("r33_group_sighup_exit_code=129")
print("r33_filter_dead_after_cleanup=true")
print("runsh_stderr_filter_hup_immunity_test=GREEN")
