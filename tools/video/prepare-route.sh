#!/usr/bin/env bash
# Prepare a filmed route for Spinline: a video that seeks and changes speed
# smoothly, and the route index that maps each video second to a distance
# and gradient.
#
# Usage: tools/video/prepare-route.sh <raw-video> <track.gpx> <offset-seconds> <name>
#   offset: seconds from the first GPX point to the first video frame.
# Writes Content/Routes/<name>.mp4 and Content/Routes/<name>.json.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
video=$1 gpx=$2 offset=$3 name=$4
out="$root/Content/Routes/$name"

# A keyframe every second (-g 30 at 30 fps) and no scene-cut keyframes: seeks
# land close to the target and playback-rate changes stay smooth. No audio.
ffmpeg -y -i "$video" -an -vf "scale=1280:-2,fps=30" \
    -c:v libx264 -preset slow -crf 26 -g 30 -keyint_min 30 -sc_threshold 0 \
    -pix_fmt yuv420p -movflags +faststart "$out.mp4"

duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out.mp4")
"$root/tools/dev.sh" run sim route-index --gpx "$gpx" --offset "$offset" --duration "$duration" --output "$out.json"
