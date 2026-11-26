#!/usr/bin/env bash
# Generate the test-pattern route shipped with the app until a filmed route
# replaces it: FFmpeg's test pattern as the video, and a synthetic GPX track
# (north at 4 to 8 m/s over a hill that climbs and descends at up to about 6 %).
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

seconds=120
awk -v n="$seconds" 'BEGIN {
    pi = 3.14159265358979
    print "<?xml version=\"1.0\"?><gpx version=\"1.1\" creator=\"make-test-route\"><trk><trkseg>"
    lat = 52.3700; d = 0
    for (t = 0; t <= n; t++) {
        v = 6 + 2 * sin(t / 12)
        d += v; lat += v / 111195
        ele = 15 * (1 - cos(2 * pi * d / 800)) / 2
        printf "<trkpt lat=\"%.7f\" lon=\"5.2100000\"><ele>%.2f</ele><time>2026-11-24T10:%02d:%02dZ</time></trkpt>\n", lat, ele, int(t / 60), t % 60
    }
    print "</trkseg></trk></gpx>"
}' > "$work/test.gpx"

ffmpeg -v error -y -f lavfi -i "testsrc2=size=384x216:rate=30:duration=$seconds" \
    -c:v libx264 -preset slow -crf 40 -g 30 -keyint_min 30 -sc_threshold 0 -pix_fmt yuv420p \
    -movflags +faststart "$root/Content/Routes/test-pattern.mp4"

"$root/tools/dev.sh" run sim route-index --gpx "$work/test.gpx" --offset 0 --duration "$seconds" \
    --output "$root/Content/Routes/test-pattern.json"
