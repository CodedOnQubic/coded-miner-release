from pathlib import Path
import re

p = Path("run.sh")
s = p.read_text()
orig = s

pattern = re.compile(
r'''    darwin/arm64\|darwin/aarch64\)
      PLATFORM="macos-arm64"
      # .*?
      ASSET_URL="\$\{CODED_MAC_ARM_LATEST_URL:-.*?\}"
      ASSET_URLS="\$\{CODED_MAC_ARM_LATEST_URLS:-.*?\}"
      ;;
''',
re.S
)

new = '''    darwin/arm64|darwin/aarch64)
      PLATFORM="macos-arm64"
      # M1091V32A2_PUBLIC_MAC_RELEASE_ASSET_FIRST
      # Prefer real button-published GitHub release assets.
      # Raw main tarballs are fallback only because they can lag behind release/latest.
      ASSET_URL="${CODED_MAC_ARM_LATEST_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64-latest.tar.gz}"
      ASSET_URLS="${CODED_MAC_ARM_LATEST_URLS:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64-latest.tar.gz https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64.tar.gz https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest-macos-arm64.tar.gz https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/coded-miner-macos-arm64-latest.tar.gz https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/coded-miner-macos-arm64.tar.gz}"
      ;;
'''

s2, n = pattern.subn(new, s, count=1)
if n != 1:
    raise SystemExit("ERROR macOS asset block not found/replaced")

p.write_text(s2)
print("changed=", s2 != orig)
print("OK M1091V32A2 Mac public runner prefers GitHub release latest asset")
