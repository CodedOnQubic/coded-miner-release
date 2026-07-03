from pathlib import Path

p = Path("run.sh")
s = p.read_text()
orig = s

marker = "M1091V33G_PUBLIC_UPDATE_60S"
if marker in s:
    print("already patched")
    raise SystemExit(0)

s = s.replace(
    "# M1091V33F_PUBLIC_CONSOLE_FROM_RELEASE_REPO",
    "# M1091V33F_PUBLIC_CONSOLE_FROM_RELEASE_REPO\n# M1091V33G_PUBLIC_UPDATE_60S",
    1,
)

s = s.replace(
    '# Central public auto-update interval. Override with CODED_PUBLIC_UPDATE_SEC=...',
    '# Central public auto-update interval. Override with CODED_PUBLIC_UPDATE_SEC=...',
    1,
)

s = s.replace(
    'CODED_PUBLIC_UPDATE_SEC="${CODED_PUBLIC_UPDATE_SEC:-300}"',
    'CODED_PUBLIC_UPDATE_SEC="${CODED_PUBLIC_UPDATE_SEC:-60}"',
    1,
)

s = s.replace(
    'export CODED_PUBLIC_UPDATE_SEC="$CODED_PUBLIC_UPDATE_SEC"',
    'export CODED_PUBLIC_UPDATE_SEC="${CODED_PUBLIC_UPDATE_SEC:-60}"',
    1,
)

s = s.replace(
    'exec bash -c "$(curl -fsSL "${CODED_PUBLIC_RUNSH_URL}?cb=$(date +%s)")"',
    'exec bash -c "$(curl -fsSL --retry 3 "${CODED_PUBLIC_RUNSH_URL}?cb=$(date +%s)")"',
    1,
)

s = s.replace(
    '# If the package misses coded-public-console.py, fetch it directly from coded-miner.',
    '# If the package misses coded-public-console.py, fetch it directly from coded-miner-release.',
    1,
)

p.write_text(s)

print("changed=", s != orig)
print("OK M1091V33G public auto-update interval is 60s")
