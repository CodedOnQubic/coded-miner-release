#!/bin/bash
# CODED_MACOS_VANILLA_BOOTSTRAP_V1306: system shell/curl/plutil/tar only until
# the digest-verified package supplies its own Python. No Homebrew/Xcode/install.
set -Eeuo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PYTHONDONTWRITEBYTECODE=1
unset PYTHONHOME PYTHONUSERBASE PYTHONPATH
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || { echo 'ERROR: Apple Silicon macOS required' >&2; exit 65; }
channel=latest
backend=neon
selected=""
threads=0
wallet="${WALLET:-${QUBIC_WALLET:-}}"
worker="${WORKER:-${QUBIC_WORKER:-}}"
pool="${POOL:-pool.codedonqubic.com:7777}"
choose_backend() {
  [[ -z "$selected" || "$selected" == "$1" ]] || { echo 'ERROR: conflicting CPU/GPU/backend flags' >&2; exit 64; }
  selected="$1"; backend="$1"
}
while (($#)); do
  case "$1" in
    -beta|--beta) channel=beta ;;
    -latest|--latest) channel=latest ;;
    -gpu|--gpu|-hybrid) choose_backend hybrid ;;
    -gpu_only|--gpu-only|-metal) choose_backend metal ;;
    -neon|-auto) choose_backend neon ;;
    --backend=*) value="${1#*=}"; [[ "$value" != auto ]] || value=neon; choose_backend "$value" ;;
    --backend) shift; (($#)) || exit 64; value="$1"; [[ "$value" != auto ]] || value=neon; choose_backend "$value" ;;
    --wallet|--worker|--pool|--threads)
      option="$1"; shift; (($#)) || exit 64
      case "$option" in --wallet) wallet="$1";; --worker) worker="$1";; --pool) pool="$1";; --threads) threads="$1";; esac ;;
    -[0-9]*) threads="${1#-}" ;;
    --help|-h)
      echo 'CODED Mac: WALLET=... WORKER=... bash run.sh --beta [-gpu|-gpu_only] [-8]'
      echo 'Default CPU/NEON; -gpu CPU+Metal; -gpu_only Metal-only. Apple Silicon, macOS 12+.'; exit 0 ;;
    *) echo "ERROR: unsupported Mac argument: $1" >&2; exit 64 ;;
  esac
  shift
done
[[ "$backend" =~ ^(neon|metal|hybrid)$ && "$threads" =~ ^[0-9]+$ && "$threads" -le 1024 ]] || exit 64
[[ "$wallet" =~ ^[A-Z]{60}$ && "$worker" =~ ^[A-Za-z0-9_.-]{1,80}$ ]] || { echo 'ERROR: set a valid WALLET and WORKER' >&2; exit 64; }
channel_url="${CODED_MAC_CHANNEL_URL:-https://api.codedonqubic.com/admin/release/channel-status}"
release_api="${CODED_MAC_RELEASE_API:-https://api.github.com/repos/CodedOnQubic/coded-miner-release/releases/tags}"
download_base="${CODED_MAC_DOWNLOAD_BASE:-https://github.com/CodedOnQubic/coded-miner-release/releases/download}"
for url in "$channel_url" "$release_api" "$download_base"; do
  case "$url" in
    https://*) ;;
    http://127.0.0.1:*|http://localhost:*) [[ "${CODED_ALLOW_FEATURE_VALIDATION:-0}" == 1 ]] || exit 64 ;;
    *) echo 'ERROR: untrusted download transport' >&2; exit 64 ;;
  esac
done
umask 077
cache_parent="${CODED_MAC_PACKAGE_CACHE:-$HOME/.coded-miner/packages/macos}"
mkdir -p "$cache_parent"
stage="$(mktemp -d "$cache_parent/.stage.XXXXXX")"
echo "Mac package staging: $stage"
curl -fsSL --connect-timeout 5 --max-time 20 "$channel_url" -o "$stage/channel.json"
if [[ "$channel" == beta ]]; then prefix=beta; alias=coded-miner-macos-arm64-beta-latest.tar.gz
else prefix=public_latest; alias=coded-miner-macos-arm64-latest.tar.gz; fi
version="$(plutil -extract "$prefix.version" raw -o - "$stage/channel.json")"
commit="$(plutil -extract "$prefix.commit" raw -o - "$stage/channel.json")"
mac_ready="$(plutil -extract "$prefix.assets.macos.ok" raw -o - "$stage/channel.json" 2>/dev/null || true)"
[[ "$version" =~ ^[A-Za-z0-9_.+-]+$ && "$commit" =~ ^[0-9a-f]{40}$ && "$mac_ready" == true ]] || {
  echo "ERROR: no qualified native Mac package on $channel; refusing legacy/channel fallback" >&2; exit 69;
}
[[ "$version" == *"$commit"* ]] || { echo 'ERROR: source/version identity mismatch' >&2; exit 69; }
cache="$cache_parent/$version"
check_package() {
  local directory="$1"
  [[ -x "$directory/coded-miner/python/bin/python3" && -f "$directory/coded-miner/coded-package-check.py" ]] || return 1
  "$directory/coded-miner/python/bin/python3" -I -B "$directory/coded-miner/coded-package-check.py" "$directory/coded-miner" "$commit" "$version"
}
if [[ ! -d "$cache" ]]; then
  curl -fsSL --connect-timeout 5 --max-time 30 "$release_api/$version" -o "$stage/release.json"
  index=0; expected=""; artifact_url=""
  while [[ "$index" -lt 100 ]]; do
    name="$(plutil -extract "assets.$index.name" raw -o - "$stage/release.json" 2>/dev/null || true)"
    [[ -n "$name" ]] || break
    if [[ "$name" == "$alias" ]]; then
      expected="$(plutil -extract "assets.$index.digest" raw -o - "$stage/release.json")"
      artifact_url="$(plutil -extract "assets.$index.browser_download_url" raw -o - "$stage/release.json")"
      break
    fi
    index=$((index+1))
  done
  [[ "$expected" =~ ^sha256:[0-9a-f]{64}$ && "$artifact_url" == "$download_base/$version/$alias" ]] || {
    echo 'ERROR: exact versioned Mac asset/digest not found' >&2; exit 69;
  }
  curl -fL --connect-timeout 5 --max-time 300 "$artifact_url" -o "$stage/package.tar.gz"
  actual="$(shasum -a 256 "$stage/package.tar.gz" | awk '{print $1}')"
  [[ "$actual" == "${expected#sha256:}" ]] || { echo 'ERROR: archive SHA256 mismatch' >&2; exit 69; }
  # The complete archive digest was verified before any extraction or execution.
  tar -tzf "$stage/package.tar.gz" | awk 'BEGIN {bad=0} /^\// || /(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
  tar -xzf "$stage/package.tar.gz" -C "$stage"
  check_package "$stage" || { echo 'ERROR: incomplete/unqualified native package' >&2; exit 69; }
  # Atomic installation without overwriting any prior package or nesting one
  # staging tree inside a concurrently installed cache directory.
  "$stage/coded-miner/python/bin/python3" -I -B -c 'import os,sys
try: os.rename(sys.argv[1],sys.argv[2])
except OSError:
    if not os.path.isdir(sys.argv[2]): raise' "$stage" "$cache"
fi
check_package "$cache" || { echo 'ERROR: cached package failed integrity check; preserved for inspection' >&2; exit 69; }
# The existing foreground-parent update handoff is retained. A background
# check stages/verifies only; it never starts, stops or signals a miner.
if [[ "${CODED_MAC_STAGE_ONLY:-0}" == 1 ]]; then
  echo "MACOS_STAGE_READY source=$commit"
  exit 0
fi
echo "CODED Mac source=$commit backend=$backend channel=$channel"
export CODED_MACOS_ONELINER_SOURCE="$commit"
export CODED_MACOS_ONELINER_CHANNEL="$channel"
export CODED_MACOS_BOOTSTRAP_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
exec /bin/bash "$cache/coded-miner/coded-miner-macos" --pool "$pool" --wallet "$wallet" --worker "$worker" --backend "$backend" --threads "$threads"
