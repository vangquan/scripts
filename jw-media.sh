#!/usr/bin/env bash
# shellcheck disable=SC2016   # single-quoted $ inside heredocs is intentional
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════════╗
# ║  JW Media Browser                                               ║
# ║  fzf-powered media launcher with live camera feed               ║
# ║                                                                 ║
# ║  Platform : macOS only (avfoundation · osascript · caffeinate)  ║
# ║  fzf      : ≥ 0.44 required (focus:transform-header)           ║
# ║                                                                 ║
# ║  Usage    : jw-media <file-or-folder>                           ║
# ║                                                                 ║
# ║  Key bindings                                                   ║
# ║    Enter      Play selected file(s)                             ║
# ║    Tab        Multi-select                                      ║
# ║    Ctrl-R     Refresh file list                                 ║
# ║    Esc        Exit                                              ║
# ║                                                                 ║
# ║  Overridable env vars (export before running)                   ║
# ║    CAM_SOURCE   avfoundation device string                      ║
# ║                 default: "qPhone Camera:none"                   ║
# ║    CAM_RES      capture resolution  default: 1920x1080          ║
# ║    CAM_FPS      capture frame rate  default: 60                 ║
# ║    CAM_SCREEN   mpv --screen index  default: 1                  ║
# ╚══════════════════════════════════════════════════════════════════╝

# ── Constants (overridable via env) ──────────────────────────────────
readonly CAM_SOCKET="/tmp/mpv-camera-socket"
readonly CAM_PIDFILE="/tmp/mpv-camera.pid"
readonly CAM_LOG="/tmp/mpv-camera.log"
readonly CAM_SOURCE="${CAM_SOURCE:-qPhone Camera:none}"
readonly CAM_RES="${CAM_RES:-1920x1080}"
readonly CAM_FPS="${CAM_FPS:-60}"
readonly CAM_SCREEN="${CAM_SCREEN:-1}"
readonly CAM_SOCKET_TIMEOUT=5

# ── Colors ───────────────────────────────────────────────────────────
RED=$'\033[0;31m'; YELLOW=$'\033[0;33m'; RESET=$'\033[0m'

die()  { echo "${RED}Error:${RESET} $*" >&2; exit 1; }
warn() { echo "${YELLOW}Warning:${RESET} $*" >&2; }

# ── Platform guard ───────────────────────────────────────────────────
[[ "$(uname)" == "Darwin" ]] || die "jw-media requires macOS."

# ── Usage ────────────────────────────────────────────────────────────
[[ -z "${1:-}" ]] && die "Usage: $(basename "$0") <file-or-folder>"

if   [[ -f "$1" ]]; then folder=$(dirname -- "$1")
elif [[ -d "$1" ]]; then folder="$1"
else die "Invalid path: $1"
fi

# ── Dependency check ─────────────────────────────────────────────────
for cmd in fzf find chafa ffmpeg ffprobe mpv osascript caffeinate socat; do
  command -v "$cmd" >/dev/null 2>&1 || die "'$cmd' is required but not found."
done

# fzf ≥ 0.44 required for focus:transform-header
fzf_ver=$(fzf --version | awk '{print $1}')
fzf_major=$(echo "$fzf_ver" | cut -d. -f1)
fzf_minor=$(echo "$fzf_ver" | cut -d. -f2)
if (( fzf_major == 0 && fzf_minor < 44 )); then
  die "fzf ≥ 0.44 required (found $fzf_ver). Run: brew upgrade fzf"
fi
unset fzf_ver fzf_major fzf_minor

# ── Capture frontmost app for focus restore ──────────────────────────
FOCUS_APP=$(osascript -e \
  'tell application "System Events" to get name of first process whose frontmost is true' \
  2>/dev/null || echo "Terminal")
readonly FOCUS_APP

# ── Safe PID defaults (FIX: prevents set -u errors in cleanup if    ──
# ── script exits before these are assigned)                         ──
CAFFEINATE_PID=""
PREWARM_PID=""

# ── Prevent sleep ────────────────────────────────────────────────────
caffeinate -dimsu &
CAFFEINATE_PID=$!
readonly CAFFEINATE_PID

# ── Menu bar ─────────────────────────────────────────────────────────
ORIGINAL_MENU_STATE=$(
  osascript -e 'tell application "System Events" to tell dock preferences to get autohide menu bar' \
  2>/dev/null || echo "false"
)

_set_menubar() {
  osascript -e "tell application \"System Events\" to tell dock preferences \
    to set autohide menu bar to $1" >/dev/null 2>&1 || true
}

# ── Camera helpers ────────────────────────────────────────────────────
_cam_running() {
  [[ -S "$CAM_SOCKET" ]] \
    && [[ -f "$CAM_PIDFILE" ]] \
    && kill -0 "$(cat "$CAM_PIDFILE")" 2>/dev/null
}

start_camera() {
  _cam_running && return
  rm -f "$CAM_SOCKET"

  # -probesize 32 + -analyzeduration 0: skip stream analysis for a known
  # live source — cuts startup from ~3-5 s to under 1 s.
  # -fflags nobuffer+discardcorrupt + -thread_queue_size 512: reduce
  # latency and suppress queue overflow warnings on fast sources.
  nohup bash -c '
    ffmpeg \
      -f avfoundation \
      -pixel_format nv12 \
      -framerate '"$CAM_FPS"' \
      -video_size '"$CAM_RES"' \
      -probesize 32 \
      -analyzeduration 0 \
      -fflags nobuffer+discardcorrupt \
      -thread_queue_size 512 \
      -i "'"$CAM_SOURCE"'" \
      -c:v rawvideo \
      -f nut - \
    | mpv \
        --no-config \
        --no-terminal \
        --really-quiet \
        --hwdec=auto \
        --vo=gpu \
        --no-cache \
        --untimed \
        --profile=low-latency \
        --fs --no-native-fs --screen='"$CAM_SCREEN"' --ontop --no-border \
        --demuxer-lavf-o=fflags=nobuffer \
        --input-ipc-server="'"$CAM_SOCKET"'" \
        -
  ' >"$CAM_LOG" 2>&1 &

  echo $! > "$CAM_PIDFILE"

  # Poll at 0.05 s — halves worst-case socket wait vs 0.1 s
  local i max_iter=$(( CAM_SOCKET_TIMEOUT * 20 ))
  for (( i=0; i<max_iter; i++ )); do
    [[ -S "$CAM_SOCKET" ]] && return
    sleep 0.01
  done
  warn "Camera socket did not appear after ${CAM_SOCKET_TIMEOUT}s — check $CAM_LOG"
}

stop_camera() {
  if [[ -S "$CAM_SOCKET" ]]; then
    echo '{ "command": ["quit"] }' | socat - "$CAM_SOCKET" >/dev/null 2>&1 || true
  fi
  if [[ -f "$CAM_PIDFILE" ]]; then
    local pid; pid=$(cat "$CAM_PIDFILE")
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$CAM_PIDFILE"
  fi
  pkill -9 -f "mpv.*$CAM_SOCKET" 2>/dev/null || true
  rm -f "$CAM_SOCKET"
}

# ── Cleanup ───────────────────────────────────────────────────────────
cleanup() {
  _set_menubar "$ORIGINAL_MENU_STATE"
  # FIX: use ${VAR:-} so set -u never fires if either PID was never assigned
  kill "${CAFFEINATE_PID:-}" 2>/dev/null || true
  kill "${PREWARM_PID:-}"    2>/dev/null || true
  stop_camera
  [[ -d "${THUMB_DIR:-}" ]] && rm -rf "$THUMB_DIR"
  [[ -d "${META_DIR:-}"  ]] && rm -rf "$META_DIR"
  rm -f "${ENTRIES_SCRIPT:-}"  "${PLAY_SCRIPT:-}" \
        "${PREVIEW_SCRIPT:-}"  "${METADATA_SCRIPT:-}" \
        "${PREWARM_SCRIPT:-}"  "${PREWARM_WORKER:-}"
}
trap cleanup EXIT INT TERM

# ── Init ──────────────────────────────────────────────────────────────
_set_menubar true
start_camera

# ── Cache dirs ────────────────────────────────────────────────────────
THUMB_DIR=$(mktemp -d)   # cached video thumbnail jpegs
META_DIR=$(mktemp -d)    # cached metadata one-liners

# ── Temp scripts ──────────────────────────────────────────────────────
ENTRIES_SCRIPT=$(mktemp)
PLAY_SCRIPT=$(mktemp)
PREVIEW_SCRIPT=$(mktemp)
METADATA_SCRIPT=$(mktemp)
PREWARM_SCRIPT=$(mktemp)
PREWARM_WORKER=$(mktemp)

# ── Entries: list media files ─────────────────────────────────────────
# ${f##*/} is pure bash — avoids a basename subprocess per file
cat > "$ENTRIES_SCRIPT" <<EOF
#!/usr/bin/env bash
find "$folder" -maxdepth 1 \\( -type f -o -type l \\) \\( \\
  -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.avi" \\
  -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \\
\\) | sort | while IFS= read -r f; do
  printf "%s\t%s\n" "\${f##*/}" "\$f"
done
EOF

# ── Play ──────────────────────────────────────────────────────────────
# --no-config : skip ~/.config/mpv/mpv.conf + all user scripts
# --hwdec=auto: hardware decoding
# --vo=gpu    : force GPU backend, skip backend probe
# --really-quiet --no-terminal: suppress per-frame terminal output
cat > "$PLAY_SCRIPT" <<PLAY
#!/usr/bin/env bash
set -euo pipefail

# Stop camera
if [[ -S "$CAM_SOCKET" ]]; then
  echo '{ "command": ["quit"] }' | socat - "$CAM_SOCKET" >/dev/null 2>&1 || true
fi
if [[ -f "$CAM_PIDFILE" ]]; then
  pid=\$(cat "$CAM_PIDFILE")
  kill "\$pid" 2>/dev/null || true
  rm -f "$CAM_PIDFILE"
fi
pkill -9 -f "mpv.*$CAM_SOCKET" 2>/dev/null || true
rm -f "$CAM_SOCKET"

# Play (single or multi-select playlist)
files=("\$@")
if [[ \${#files[@]} -eq 1 ]]; then
  case "\${files[0]}" in
    *.jpg|*.jpeg|*.png|*.gif)
      mpv --no-config --no-terminal --really-quiet \
          --hwdec=auto --vo=gpu \
          --fs --no-native-fs --screen=$CAM_SCREEN --ontop --no-border \
          --image-display-duration=5 \
          "\${files[0]}"
      ;;
    *)
      mpv --no-config --no-terminal --really-quiet \
          --hwdec=auto --vo=gpu \
          --fs --no-native-fs --screen=$CAM_SCREEN --ontop --no-border \
          "\${files[0]}"
      ;;
  esac
else
  mpv --no-config --no-terminal --really-quiet \
      --hwdec=auto --vo=gpu \
      --fs --no-native-fs --screen=$CAM_SCREEN --ontop --no-border \
      --image-display-duration=5 \
      "\${files[@]}"
fi

# Restart camera with same speed flags
nohup bash -c '
  ffmpeg \\
    -f avfoundation \\
    -pixel_format nv12 \\
    -framerate $CAM_FPS \\
    -video_size $CAM_RES \\
    -probesize 32 \\
    -analyzeduration 0 \\
    -fflags nobuffer+discardcorrupt \\
    -thread_queue_size 512 \\
    -i "$CAM_SOURCE" \\
    -c:v rawvideo \\
    -f nut - \\
  | mpv \\
      --no-config \\
      --no-terminal \\
      --really-quiet \\
      --hwdec=auto \\
      --vo=gpu \\
      --no-cache --untimed --profile=low-latency \\
      --fs --no-native-fs --screen=$CAM_SCREEN --ontop --no-border \\
      --demuxer-lavf-o=fflags=nobuffer \\
      --input-ipc-server="$CAM_SOCKET" \\
      -
' >"$CAM_LOG" 2>&1 &
echo \$! > "$CAM_PIDFILE"

osascript -e "tell application \"$FOCUS_APP\" to activate" >/dev/null 2>&1 || true
PLAY

# ── Preview: chafa kitty image only ──────────────────────────────────
# Metadata is displayed in the fzf header (via METADATA_SCRIPT +
# transform-header) so it is never obscured by the kitty image overlay.
cat > "$PREVIEW_SCRIPT" <<PREVIEW
#!/usr/bin/env bash
file="\$1"
w=\${FZF_PREVIEW_COLUMNS:-40}
h=\${FZF_PREVIEW_LINES:-20}
THUMB_DIR="$THUMB_DIR"

# Pure bash cksum trim — no awk subprocess
raw=\$(printf '%s' "\$file" | cksum)
thumb_key=\${raw%% *}
thumb_path="\$THUMB_DIR/\${thumb_key}.jpg"

case "\$file" in
  *.jpg|*.jpeg|*.png|*.gif)
    chafa --size="\${w}x\${h}" --format=kitty --colors=full --dither=none "\$file" 2>/dev/null || true
    ;;
  *)
    # Thumbnail is likely pre-warmed; ffmpeg only runs on a cold cache miss
    if [[ ! -f "\$thumb_path" ]]; then
      ffmpeg -loglevel error -ss 1 -i "\$file" \
        -vframes 1 -q:v 3 "\$thumb_path" 2>/dev/null || true
    fi
    [[ -f "\$thumb_path" ]] && \
      chafa --size="\${w}x\${h}" --format=kitty --colors=full --dither=none "\$thumb_path" 2>/dev/null || true
    ;;
esac
PREVIEW

# ── Metadata: one-line summary → fzf header ──────────────────────────
# Called by focus:transform-header on every cursor move.
# Cache hit  → cat one tiny text file  (near-instant)
# Cache miss → single ffprobe call for all fields, then cache
cat > "$METADATA_SCRIPT" <<META
#!/usr/bin/env bash
file="\$1"
META_DIR="$META_DIR"

[[ -z "\$file" ]] && echo "  🔴 Camera: Live" && exit 0

raw=\$(printf '%s' "\$file" | cksum)
cache_key=\${raw%% *}
cache_file="\$META_DIR/\${cache_key}.txt"

[[ -f "\$cache_file" ]] && { cat "\$cache_file"; exit 0; }

size=\$(du -sh "\$file" 2>/dev/null | cut -f1 || echo "?")

case "\$file" in
  *.jpg|*.jpeg|*.png|*.gif)
    width="" height=""
    while IFS='=' read -r key val; do
      case "\$key" in
        width)  width="\$val"  ;;
        height) height="\$val" ;;
      esac
    done < <(ffprobe -v quiet -read_intervals "%+#1" \
        -select_streams v:0 \
        -show_entries stream=width,height \
        -of default=noprint_wrappers=1 "\$file" 2>/dev/null)
    line="  🔴 Live   ─   📐 \${width:-?}x\${height:-?}   💾 \${size}"
    ;;
  *)
    duration="" bitrate="" codec="" width="" height=""
    while IFS='=' read -r key val; do
      case "\$key" in
        duration)   duration="\$val" ;;
        bit_rate)   bitrate="\$val"  ;;
        codec_name) codec="\$val"    ;;
        width)      width="\$val"    ;;
        height)     height="\$val"   ;;
      esac
    done < <(ffprobe -v quiet -read_intervals "%+#1" \
        -select_streams v:0 \
        -show_entries format=duration,bit_rate:stream=codec_name,width,height \
        -of default=noprint_wrappers=1 "\$file" 2>/dev/null)

    if [[ -n "\$duration" && "\$duration" != "N/A" ]]; then
      dur_int=\${duration%.*}
      hh=\$(( dur_int / 3600 ))
      mm=\$(( (dur_int % 3600) / 60 ))
      ss=\$(( dur_int % 60 ))
      dur_fmt=\$(printf "%02d:%02d:%02d" "\$hh" "\$mm" "\$ss")
    else
      dur_fmt="?"
    fi

    if [[ -n "\$bitrate" && "\$bitrate" != "N/A" ]]; then
      br_fmt=\$(awk "BEGIN { printf \"%.1f Mbps\", \$bitrate / 1000000 }")
    else
      br_fmt="?"
    fi

    line="  🔴 Live   ─   ⏱ \${dur_fmt}   📐 \${width:-?}x\${height:-?}   🎞 \${codec:-?}   ⚡ \${br_fmt}   💾 \${size}"
    ;;
esac

printf '%s' "\$line" | tee "\$cache_file"
META

# ── Pre-warmer worker (one file per invocation, called by xargs -P) ──
cat > "$PREWARM_WORKER" <<WORKER
#!/usr/bin/env bash
file="\$1"
THUMB_DIR="$THUMB_DIR"
META_DIR="$META_DIR"

raw=\$(printf '%s' "\$file" | cksum)
cache_key=\${raw%% *}
meta_file="\$META_DIR/\${cache_key}.txt"
thumb_path="\$THUMB_DIR/\${cache_key}.jpg"
size=\$(du -sh "\$file" 2>/dev/null | cut -f1 || echo "?")

case "\$file" in
  *.jpg|*.jpeg|*.png|*.gif)
    if [[ ! -f "\$meta_file" ]]; then
      width="" height=""
      while IFS='=' read -r key val; do
        case "\$key" in
          width)  width="\$val"  ;;
          height) height="\$val" ;;
        esac
      done < <(ffprobe -v quiet -read_intervals "%+#1" \
          -select_streams v:0 \
          -show_entries stream=width,height \
          -of default=noprint_wrappers=1 "\$file" 2>/dev/null)
      printf '  🔴 Live   ─   📐 %sx%s   💾 %s' \
        "\${width:-?}" "\${height:-?}" "\$size" > "\$meta_file"
    fi
    ;;

  *)
    if [[ ! -f "\$meta_file" ]]; then
      duration="" bitrate="" codec="" width="" height=""
      while IFS='=' read -r key val; do
        case "\$key" in
          duration)   duration="\$val" ;;
          bit_rate)   bitrate="\$val"  ;;
          codec_name) codec="\$val"    ;;
          width)      width="\$val"    ;;
          height)     height="\$val"   ;;
        esac
      done < <(ffprobe -v quiet -read_intervals "%+#1" \
          -select_streams v:0 \
          -show_entries format=duration,bit_rate:stream=codec_name,width,height \
          -of default=noprint_wrappers=1 "\$file" 2>/dev/null)

      if [[ -n "\$duration" && "\$duration" != "N/A" ]]; then
        dur_int=\${duration%.*}
        hh=\$(( dur_int / 3600 ))
        mm=\$(( (dur_int % 3600) / 60 ))
        ss=\$(( dur_int % 60 ))
        dur_fmt=\$(printf "%02d:%02d:%02d" "\$hh" "\$mm" "\$ss")
      else
        dur_fmt="?"
      fi

      if [[ -n "\$bitrate" && "\$bitrate" != "N/A" ]]; then
        br_fmt=\$(awk "BEGIN { printf \"%.1f Mbps\", \$bitrate / 1000000 }")
      else
        br_fmt="?"
      fi

      printf '  🔴 Live   ─   ⏱ %s   📐 %sx%s   🎞 %s   ⚡ %s   💾 %s' \
        "\$dur_fmt" "\${width:-?}" "\${height:-?}" "\${codec:-?}" "\$br_fmt" "\$size" \
        > "\$meta_file"
    fi

    if [[ ! -f "\$thumb_path" ]]; then
      ffmpeg -loglevel error -ss 1 -i "\$file" \
        -vframes 1 -q:v 3 "\$thumb_path" 2>/dev/null || true
    fi
    ;;
esac
WORKER

# ── Pre-warmer orchestrator ───────────────────────────────────────────
# xargs -P 4: 4 parallel workers → ~4× faster than sequential
# nice -n 19: lowest CPU priority — never competes with fzf or camera
cat > "$PREWARM_SCRIPT" <<PREWARM
#!/usr/bin/env bash
find "$folder" -maxdepth 1 \\( -type f -o -type l \\) \\( \\
  -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.avi" \\
  -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \\
\\) | sort | xargs -P 4 -I{} bash "$PREWARM_WORKER" {}
PREWARM

chmod +x "$ENTRIES_SCRIPT" "$PLAY_SCRIPT"   "$PREVIEW_SCRIPT" \
         "$METADATA_SCRIPT" "$PREWARM_SCRIPT" "$PREWARM_WORKER"

nice -n 19 bash "$PREWARM_SCRIPT" &
PREWARM_PID=$!

# ── Launch fzf ────────────────────────────────────────────────────────
#
# Layout:
#   ╭─ border ────────────────────────────────────────────────────╮
#   │  header  ← file metadata (transform-header, never covered)  │
#   ├─────────────────────────────────────────────────────────────┤
#   │  file list                       │  preview (kitty image)   │
#   ├─ footer-border ──────────────────┴──────────────────────────┤
#   │  footer  ← static key hints                                 │
#   ╰─────────────────────────────────────────────────────────────╯
"$ENTRIES_SCRIPT" | fzf \
  --ansi \
  --delimiter='\t' \
  --with-nth=1 \
  --height=100% \
  --reverse \
  --border=rounded \
  --prompt=" JW Media ▶  " \
  --header="  🔴 Camera: Live" \
  --header-border=bottom \
  --footer=" Enter=Play   Tab=Select   Esc=Exit   Ctrl-R=Refresh" \
  --footer-border=top \
  --cycle \
  --sync \
  --multi \
  --highlight-line \
  --preview "bash '$PREVIEW_SCRIPT' {2}" \
  --preview-window=right:40%:wrap \
  --preview-border=left \
  --bind "focus:transform-header(bash '$METADATA_SCRIPT' {2})" \
  --bind "enter:execute($PLAY_SCRIPT {+2})" \
  --bind "ctrl-r:reload($ENTRIES_SCRIPT)"
