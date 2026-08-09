#!/usr/bin/env python3

from __future__ import annotations

import subprocess
import tempfile

from pathlib import Path


ROOT = Path(
    __file__
).resolve().parents[1]

RUN_SH = ROOT / "run.sh"


text = RUN_SH.read_text(
    encoding="utf-8",
)


start = text.index(
    "coded_stop_old_public_instances() {\n"
)

call = text.index(
    'coded_stop_old_public_instances "$BASE"\n',
    start,
)


function = text[
    start:call
]


pipeline = (
    'pgrep -f "$needle" 2>/dev/null '
    '| while read -r pid; do'
)


assert function.count(
    pipeline
) == 2


assert function.count(
    "    done || true\n"
) == 2


with tempfile.TemporaryDirectory() as raw:

    missing = (
        Path(raw)
        / "no-existing-public-runtime"
    )


    harness = (
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        "\n"
        "coded_ui_loader() { :; }\n"
        "pgrep() { return 1; }\n"
        "sleep() { :; }\n"
        "\n"
        + function
        + "\n"
        + 'coded_stop_old_public_instances "'
        + str(missing)
        + '"\n'
        + 'echo "STARTUP_NO_MATCH_SURVIVED"\n'
    )


    proc = subprocess.run(
        [
            "/bin/bash",
        ],
        input=harness,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )


assert proc.returncode == 0, (
    proc.returncode,
    proc.stdout,
    proc.stderr,
)


assert (
    "STARTUP_NO_MATCH_SURVIVED"
    in proc.stdout
)


print(
    "startup_pgrep_pipeline_count=2"
)

print(
    "startup_pgrep_no_match_guard_count=2"
)

print(
    "startup_no_match_exit_code=0"
)

print(
    "startup_no_match_survived=true"
)

print(
    "runsh_startup_no_match_cleanup_test=GREEN"
)
