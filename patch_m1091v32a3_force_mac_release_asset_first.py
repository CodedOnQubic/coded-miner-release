from pathlib import Path

p = Path("run.sh")
lines = p.read_text().splitlines()
out = []

i = 0
changed = False

while i < len(lines):
    line = lines[i]

    if line.strip() == "darwin/arm64|darwin/aarch64)":
        out.append(line)
        i += 1

        # Keep PLATFORM line.
        if i < len(lines) and 'PLATFORM="macos-arm64"' in lines[i]:
            out.append(lines[i])
            i += 1
        else:
            raise SystemExit("ERROR PLATFORM line missing after darwin block")

        # Skip old comments + ASSET_URL/ASSET_URLS until ";;"
        while i < len(lines) and lines[i].strip() != ";;":
            i += 1

        out.append('      # M1091V32A3_PUBLIC_MAC_RELEASE_ASSET_FIRST')
        out.append('      # Prefer real button-published GitHub release assets.')
        out.append('      # Raw main tarballs are fallback only because they can lag behind release/latest.')
        out.append('      ASSET_URL="${CODED_MAC_ARM_LATEST_URL:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64-latest.tar.gz}"')
        out.append('      ASSET_URLS="${CODED_MAC_ARM_LATEST_URLS:-https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64-latest.tar.gz https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-macos-arm64.tar.gz https://github.com/CodedOnQubic/coded-miner-release/releases/latest/download/coded-miner-latest-macos-arm64.tar.gz https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/coded-miner-macos-arm64-latest.tar.gz https://raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/coded-miner-macos-arm64.tar.gz}"')

        if i < len(lines) and lines[i].strip() == ";;":
            out.append(lines[i])
            i += 1
            changed = True
            continue

        raise SystemExit("ERROR darwin block terminator not found")

    out.append(line)
    i += 1

if not changed:
    raise SystemExit("ERROR darwin mac asset block not patched")

text = "\n".join(out) + "\n"
if "M1091V32A3_PUBLIC_MAC_RELEASE_ASSET_FIRST" not in text:
    raise SystemExit("ERROR marker missing after patch")
if "raw.githubusercontent.com/CodedOnQubic/coded-miner-release/main/coded-miner-macos-arm64-latest.tar.gz https://github.com" in text:
    raise SystemExit("ERROR raw still appears before release asset")

p.write_text(text)
print("OK M1091V32A3 force Mac release asset first")
