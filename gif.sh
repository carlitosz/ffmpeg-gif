#!/bin/sh
# gif - Convert a video into a compact, looping GIF using FFmpeg and gifsicle.
# POSIX sh; tested syntax with dash. No zsh/bash-specific features required.
#
# Usage:
#   gif video.mp4
#   gif -o demo.gif -s 540 -f 18 -m 8 video.mp4
#   gif -t 2 -d 6 video.mp4      # start at 2s, take 6s
#   gif -p quality video.mp4     # favor smoothness and detail
#   gif -p small video.mp4       # favor smaller GIFs
#
# The script aims for TARGET_MB (default: 8 MB) and NEVER publishes a file
# larger than HARD_MB (default: 15 MB). It exits nonzero if no candidate fits.
# Quality tuning is explained in GIF-README.md.
set -eu

usage() {
  cat <<'HELP'
Usage: gif [options] VIDEO

Options:
  -o PATH   Output filename (default: VIDEO.gif beside the input)
  -s PX     Initial output width, pixels (default: 540, never upscale)
  -f FPS    Initial frame rate, integer (default: 18)
  -m MB    Preferred size target in MB (default: 8)
  -M MB    Absolute size ceiling in MB (default: 15)
  -t SEC    Start time in seconds (default: 0)
  -d SEC    Clip duration in seconds (default: complete video)
  -p NAME   Preset: balanced (default), quality, small
  -h        Show help

Outputs beside the source video; never overwrites an existing file.
For a very long video, use -t and -d to select a short clip.
HELP
}

error() { printf 'gif: %s\n' "$*" >&2; exit 1; }
number() { case "$1" in ''|*[!0-9]*) return 1;; esac; [ "$1" -gt 0 ]; }
seconds() { case "$1" in ''|*[!0-9.]*) return 1;; esac; case "$1" in *.*.*) return 1;; esac; return 0; }
smaller() { [ "$1" -lt "$2" ] && printf '%s' "$1" || printf '%s' "$2"; }

WIDTH=540
FPS=18
TARGET_MB=8
HARD_MB=15
START=0
DURATION=
PRESET=balanced
OUTPUT=

while getopts 'o:s:f:m:M:t:d:p:h' flag; do
  case "$flag" in
    o) OUTPUT=$OPTARG ;;
    s) WIDTH=$OPTARG ;;
    f) FPS=$OPTARG ;;
    m) TARGET_MB=$OPTARG ;;
    M) HARD_MB=$OPTARG ;;
    t) START=$OPTARG ;;
    d) DURATION=$OPTARG ;;
    p) PRESET=$OPTARG ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
[ "$#" -eq 1 ] || { usage >&2; exit 2; }
INPUT=$1
[ -f "$INPUT" ] || error "input not found: $INPUT"
for command_name in ffmpeg gifsicle; do
  command -v "$command_name" >/dev/null 2>&1 || error "missing dependency: $command_name"
done
for val in "$WIDTH" "$FPS" "$TARGET_MB" "$HARD_MB"; do
  number "$val" || error 'width, FPS, and size limits must be positive integers'
done
[ "$TARGET_MB" -le "$HARD_MB" ] || error 'target (-m) must not exceed ceiling (-M)'
# This is an intentional product limit, not just a default.
[ "$HARD_MB" -le 15 ] || error 'hard ceiling (-M) cannot exceed 15 MB'
[ "$WIDTH" -ge 64 ] || error 'width must be at least 64 pixels'
[ "$FPS" -le 60 ] || error 'FPS must be at most 60'
seconds "$START" || error 'start must be a nonnegative number of seconds'
case "$START" in -*) error 'start must be nonnegative';; esac
if [ -n "$DURATION" ]; then
  seconds "$DURATION" || error 'duration must be a positive number of seconds'
  case "$DURATION" in 0|0.0|0.00|0.000|-*) error 'duration must be positive';; esac
fi
case "$PRESET" in balanced|quality|small) : ;; *) error 'preset must be balanced, quality, or small';; esac

if [ -z "$OUTPUT" ]; then
  case "$INPUT" in
    *.*) OUTPUT=${INPUT%.*}.gif ;;
    *) OUTPUT=$INPUT.gif ;;
  esac
fi
[ ! -e "$OUTPUT" ] || error "output already exists: $OUTPUT (use -o for another name)"

# All temporary artifacts are private to this invocation. Cleanup on failure,
# interruption, and success. Outputs are copied into place only after size check.
WORK=$(mktemp -d "${TMPDIR:-/tmp}/gif.XXXXXXXX") || error 'cannot make temp directory'
# POSIX sh has no EXIT keyword standardization issue: signal 0 is portable.
trap 'rm -rf -- "$WORK"' 0
trap 'exit 130' 2
trap 'exit 143' 15

TARGET_BYTES=$((TARGET_MB * 1000000))
HARD_BYTES=$((HARD_MB * 1000000))
BEST_BYTES=0
BEST_DESC=

# Quality tiers. Each level progressively reduces the total pixel/frame count
# and accepts a little more palette simplification / lossy GIF compression.
# Explicit -s and -f are quality caps, so tiers never exceed those limits.
case "$PRESET" in
  quality) TIERS='540:20:256:0 540:18:256:20 480:16:224:30 420:14:192:45 360:12:160:65 300:10:128:85 240:8:96:110' ;;
  balanced) TIERS='540:18:256:15 480:16:224:25 420:14:192:40 360:12:160:60 300:10:128:80 240:8:96:110' ;;
  small) TIERS='420:15:192:35 360:12:160:55 300:10:128:75 260:8:112:95 220:8:96:120 180:6:64:140' ;;
esac

printf 'Input: %s\nOutput: %s\nPreset: %s | target: %s MB | ceiling: %s MB\n' \
  "$INPUT" "$OUTPUT" "$PRESET" "$TARGET_MB" "$HARD_MB"

INDEX=0
for TIER in $TIERS; do
  INDEX=$((INDEX + 1))
  OLDIFS=$IFS
  IFS=:
  # A tier is internally defined above, not user supplied.
  set -- $TIER
  IFS=$OLDIFS
  W=$(smaller "$WIDTH" "$1")
  RATE=$(smaller "$FPS" "$2")
  COLORS=$3
  LOSSY=$4
  RAW="$WORK/raw-$INDEX.gif"
  OPT="$WORK/opt-$INDEX.gif"

  # The same fps/scale frames feed BOTH palette generation and palette usage.
  # decrease-only='min(iw,W)' avoids upscaling narrow source videos.
  # Even dimension rounding avoids quirky output dimensions/codecs.
  FILTER="[0:v]fps=$RATE,scale=w='min(iw,$W)':h=-2:flags=lanczos,split[a][b];[a]palettegen=max_colors=$COLORS:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle[out]"

  printf '\nAttempt %s: up to %spx, %s fps, %s colors, lossy=%s\n' "$INDEX" "$W" "$RATE" "$COLORS" "$LOSSY"
  # Positional args preserve spaces in source filenames. Audio is not needed.
  # -ss/-t are set before output, and only when requested.
  if [ -n "$DURATION" ]; then
    ffmpeg -hide_banner -loglevel error -nostdin -y -ss "$START" -i "$INPUT" -t "$DURATION" \
      -filter_complex "$FILTER" -map '[out]' -an -loop 0 -f gif "$RAW" || error 'FFmpeg conversion failed'
  else
    ffmpeg -hide_banner -loglevel error -nostdin -y -ss "$START" -i "$INPUT" \
      -filter_complex "$FILTER" -map '[out]' -an -loop 0 -f gif "$RAW" || error 'FFmpeg conversion failed'
  fi
  # gifsicle -O3 deduplicates frame regions; modest lossy values allow LZW
  # compression to work better. It may very occasionally enlarge the input.
  gifsicle -O3 "--lossy=$LOSSY" "$RAW" -o "$OPT" || error 'gifsicle optimization failed'
  BYTES=$(wc -c < "$OPT" | tr -d ' ')
  printf 'Size: %s bytes\n' "$BYTES"
  if [ "$BYTES" -le "$HARD_BYTES" ] && \
     { [ "$BEST_BYTES" -eq 0 ] || [ "$BYTES" -lt "$BEST_BYTES" ]; }; then
    cp "$OPT" "$WORK/best.gif"
    BEST_BYTES=$BYTES
    BEST_DESC="${W}px / ${RATE} fps / ${COLORS} colors / lossy=${LOSSY}"
  fi
  if [ "$BYTES" -le "$TARGET_BYTES" ]; then
    break
  fi
done

[ "$BEST_BYTES" -gt 0 ] || error "no GIF fit within ${HARD_MB} MB; trim with -d, or reduce width / fps"
# Copying rather than moving makes output placement work across filesystems.
# 'noclobber' via atomic hard link wherever feasible prevents accidental overwrite.
if ! ln "$WORK/best.gif" "$OUTPUT" 2>/dev/null; then
  [ ! -e "$OUTPUT" ] || error "output appeared while processing: $OUTPUT"
  # Cross-device links are unsupported, fall back to safe no-clobber copy.
  (set -C; cat "$WORK/best.gif" > "$OUTPUT") || error 'could not write output'
fi
printf '\nCreated: %s\nFinal size: %s bytes (~%s MB, rounded)\nSettings: %s\n' \
  "$OUTPUT" "$BEST_BYTES" "$(( (BEST_BYTES + 500000) / 1000000 ))" "$BEST_DESC"
if [ "$BEST_BYTES" -gt "$TARGET_BYTES" ]; then
  printf 'Note: above the preferred target, but below the hard ceiling.\n'
fi
