from pathlib import Path

p = Path("run.sh")
s = p.read_text()
orig = s

marker = "M1091V33D_GREEN_LOADER_STATUS_LINE"
if marker in s:
    print("already patched")
    raise SystemExit(0)

s = s.replace(
    "# M1091V33C_SMOOTH_FULL_WIDTH_LOADER",
    "# M1091V33C_SMOOTH_FULL_WIDTH_LOADER\n# M1091V33D_GREEN_LOADER_STATUS_LINE",
    1,
)

start = s.find("coded_ui_loader_started=0\ncoded_ui_loader_percent=0\n\ncoded_ui_loader_render() {")
if start < 0:
    raise SystemExit("ERROR V33C loader start not found")

end = s.find("\ncoded_ui_loader_finish() {", start)
if end < 0:
    raise SystemExit("ERROR loader end not found")

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

green = "\033[38;5;46m"
dim_green = "\033[38;5;22m"
reset = "\033[0m"

bar = green + ("█" * fill) + dim_green + ("░" * (width - fill)) + reset
status_line = f"{percent:3d}% {status}"
status_line = status_line[:width].center(width)

print("\r\033[K" + bar)
print("\r\033[K" + status_line)
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
    printf '\n\r\033[K%3s%% %s\n' "$percent" "$status"
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
    cur=$((cur + 1))
    if [ "$cur" -gt "$target" ]; then
      cur="$target"
    fi
    coded_ui_loader_render "$cur" "$status"
    sleep 0.012
  done

  coded_ui_loader_render "$target" "$status"
  coded_ui_loader_percent="$target"
}

'''

s = s[:start] + new_loader + s[end + 1:]

lines = []
for line in s.splitlines():
    if 'echo "Trying asset: $u"' in line:
        continue
    lines.append(line)
s = "\n".join(lines) + "\n"

s = s.replace(
    'curl -fL "$u" -o "$TAR_FILE"',
    'curl -fsSL --retry 3 "$u" -o "$TAR_FILE"',
)

p.write_text(s)

print("changed=", s != orig)
print("OK M1091V33D green full-width loader with percent in status line")
