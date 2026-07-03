from pathlib import Path

p = Path("run.sh")
s = p.read_text()
orig = s

marker = "M1091V33C_SMOOTH_FULL_WIDTH_LOADER"
if marker in s:
    print("already patched")
    raise SystemExit(0)

s = s.replace(
    'CODED_PUBLIC_BOOT_SEC="${CODED_PUBLIC_BOOT_SEC:-10}"',
    'CODED_PUBLIC_BOOT_SEC="${CODED_PUBLIC_BOOT_SEC:-15}"',
    1,
)

s = s.replace(
    'export CODED_PUBLIC_BOOT_SEC="${CODED_PUBLIC_BOOT_SEC:-10}"',
    'export CODED_PUBLIC_BOOT_SEC="${CODED_PUBLIC_BOOT_SEC:-15}"',
    1,
)

start = s.find('coded_ui_loader_started=0\n\ncoded_ui_loader() {')
if start < 0:
    raise SystemExit("ERROR loader function start not found")

end = s.find('\ncoded_ui_loader_finish() {', start)
if end < 0:
    raise SystemExit("ERROR loader function end not found")

new_loader = r'''coded_ui_loader_started=0
coded_ui_loader_percent=0

coded_ui_loader_render() {
  local percent="${1:-0}"
  local status="${2:-Starting CODED}"

  if [ "$coded_ui_loader_started" = "1" ]; then
    printf '\033[2A'
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$percent" "$status" <<'PYLOAD'
import sys

percent = int(float(sys.argv[1]))
status = sys.argv[2]

width = 78
percent = max(0, min(100, percent))
fill = int(width * percent / 100)

bar = list(("█" * fill) + ("░" * (width - fill)))
label = f" {percent:3d}% "
pos = max(0, (width - len(label)) // 2)

for i, ch in enumerate(label):
    if pos + i < width:
        bar[pos + i] = ch

plain = "".join(bar)
left = plain[:pos]
mid = plain[pos:pos + len(label)]
right = plain[pos + len(label):]

if percent < 50:
    bar_color = "\033[38;5;45m"
    label_color = "\033[30;107m"
else:
    bar_color = "\033[38;5;46m"
    label_color = "\033[30;107m"

reset = "\033[0m"

print("\r\033[K" + bar_color + left + reset + label_color + mid + reset + bar_color + right + reset)
print("\r\033[K" + status[:width].center(width))
PYLOAD
  else
    printf '\r\033[K'
    local width=78
    local fill=$((width * percent / 100))
    local i=0
    while [ "$i" -lt "$width" ]; do
      if [ "$i" -lt "$fill" ]; then
        printf '█'
      else
        printf '░'
      fi
      i=$((i + 1))
    done
    printf '\n\r\033[K%s\n' "$status"
  fi

  coded_ui_loader_started=1
}

coded_ui_loader() {
  local target="${1:-0}"
  local status="${2:-Starting CODED}"

  case "$target" in
    ''|*[!0-9]*)
      target=0
    ;;
  esac

  if [ "$target" -lt 0 ]; then
    target=0
  fi

  if [ "$target" -gt 100 ]; then
    target=100
  fi

  local cur="${coded_ui_loader_percent:-0}"

  if [ "$target" -lt "$cur" ]; then
    cur=0
    coded_ui_loader_percent=0
  fi

  while [ "$cur" -lt "$target" ]; do
    cur=$((cur + 2))
    if [ "$cur" -gt "$target" ]; then
      cur="$target"
    fi
    coded_ui_loader_render "$cur" "$status"
    sleep 0.025
  done

  if [ "$target" = "$cur" ]; then
    coded_ui_loader_render "$target" "$status"
  fi

  coded_ui_loader_percent="$target"
}

'''

s = s[:start] + new_loader + s[end + 1:]

s = s.replace('    echo "Trying asset: $u"\n', '')

s = s.replace(
    'curl -fL "$u" -o "$TAR_FILE"',
    'curl -fsSL --retry 3 "$u" -o "$TAR_FILE"',
)

s = s.replace(
    '# M1091V33B_PUBLIC_LOADER_SILENT_UPDATE',
    '# M1091V33B_PUBLIC_LOADER_SILENT_UPDATE\n# M1091V33C_SMOOTH_FULL_WIDTH_LOADER',
    1,
)

p.write_text(s)

print("changed=", s != orig)
print("OK M1091V33C smooth full-width loader, silent download, longer boot warmup")
