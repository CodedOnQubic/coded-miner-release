from pathlib import Path

p = Path("run.sh")
s = p.read_text()
orig = s

old = '''    darwin/arm64|darwin/aarch64)
      PLATFORM="macos-arm64"
      # M1091V29C4_PUBLIC_MAC_ARM_RAW_LATEST_FIRST
      ASSET_URL="${CODED_MAC_ARM_LATEST_URL:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/coded-miner-macos-arm64-latest.tar.gz}"
      ASSET_URLS="${CODED_MAC_ARM_LATEST_URLS:-https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/coded-miner-macos-arm64-latest.tar.gz https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/coded-miner-macos-arm64.tar.gz https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64-latest.tar.gz https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64.tar.gz https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest-macos-arm64.tar.gz}"
      ;;
'''

new = '''    darwin/arm64|darwin/aarch64)
      PLATFORM="macos-arm64"
      # M1091V32A2_PUBLIC_MAC_RELEASE_ASSET_FIRST
      # Raw main assets can lag behind the real button-published GitHub release asset.
      # Prefer releases/latest so public Mac gets the newest package with coded-public-console.py.
      ASSET_URL="${CODED_MAC_ARM_LATEST_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64-latest.tar.gz}"
      ASSET_URLS="${CODED_MAC_ARM_LATEST_URLS:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64-latest.tar.gz https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64.tar.gz https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest-macos-arm64.tar.gz https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/coded-miner-macos-arm64-latest.tar.gz https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/coded-miner-macos-arm64.tar.gz}"
      ;;
'''

if old not in s:
    raise SystemExit("ERROR macOS asset block not found")

s = s.replace(old, new, 1)

p.write_text(s)
print("changed=", s != orig)
print("OK M1091V32A2 Mac public runner prefers GitHub release latest asset")
