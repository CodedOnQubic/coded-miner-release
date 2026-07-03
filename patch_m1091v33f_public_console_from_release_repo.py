from pathlib import Path

p = Path("run.sh")
s = p.read_text()
orig = s

marker = "M1091V33F_PUBLIC_CONSOLE_FROM_RELEASE_REPO"
if marker in s:
    print("already patched")
    raise SystemExit(0)

s = s.replace(
    "# M1091V33D_GREEN_LOADER_STATUS_LINE",
    "# M1091V33D_GREEN_LOADER_STATUS_LINE\n# M1091V33F_PUBLIC_CONSOLE_FROM_RELEASE_REPO",
    1,
)

old = 'local console_url="${CODED_PUBLIC_CONSOLE_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner/m1091v6-clean-hive-autostart/release/hiveos/coded-miner/coded-public-console.py}"'

new = 'local console_url="${CODED_PUBLIC_CONSOLE_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/coded-public-console.py}"'

if old not in s:
    raise SystemExit("ERROR old CODED_PUBLIC_CONSOLE_URL default not found")

s = s.replace(old, new, 1)

p.write_text(s)

print("changed=", s != orig)
print("OK M1091V33F public console fallback comes from release repo")
