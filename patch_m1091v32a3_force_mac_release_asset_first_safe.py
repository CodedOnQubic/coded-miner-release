from pathlib import Path

p = Path("run.sh")
lines = p.read_text().splitlines()
out = []
changed = False
i = 0

while i < len(lines):
    line = lines[i]

    if line.strip() == "darwin/arm64|darwin/aarch64)":
        out.append(line)
        i += 1

        if i < len(lines) and 'PLATFORM="macos-arm64"' in lines[i]:
            out.append(lines[i])
            i += 1
        else:
            print("ERROR: PLATFORM line missing after darwin block")
            raise SystemExit(2)

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

        print("ERROR: darwin block terminator not found")
        raise SystemExit(3)

    out.append(line)
    i += 1

if not changed:
    print("ERROR: darwin mac asset block not patched")
    raise SystemExit(4)

text = "\n".join(out) + "\n"
p.write_text(text)
print("OK M1091V32A3 force Mac release asset first")
