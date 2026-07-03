from pathlib import Path

p = Path("run.sh")
s = p.read_text()
orig = s

marker = "M1091V33E_SHORTER_LOADER_SEQUENCE"
if marker in s:
    print("already patched")
    raise SystemExit(0)

s = s.replace(
    "# M1091V33D_GREEN_LOADER_STATUS_LINE",
    "# M1091V33D_GREEN_LOADER_STATUS_LINE\n# M1091V33E_SHORTER_LOADER_SEQUENCE",
    1,
)

s = s.replace(
    'CODED_PUBLIC_BOOT_SEC="${CODED_PUBLIC_BOOT_SEC:-15}"',
    'CODED_PUBLIC_BOOT_SEC="${CODED_PUBLIC_BOOT_SEC:-10}"',
    1,
)

s = s.replace(
    'export CODED_PUBLIC_BOOT_SEC="${CODED_PUBLIC_BOOT_SEC:-15}"',
    'export CODED_PUBLIC_BOOT_SEC="${CODED_PUBLIC_BOOT_SEC:-10}"',
    1,
)

p.write_text(s)

print("changed=", s != orig)
print("OK M1091V33E loader sequence shortened by 5 seconds")
