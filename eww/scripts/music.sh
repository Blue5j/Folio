#!/usr/bin/env bash
# Paperr · now-playing, formatted as one line of JSON for eww.
set -Eeuo pipefail

empty_json() {
    jq -cn '{
        status: "Stopped",
        artist: "put a record on",
        title: "nothing on the turntable",
        album: "a mystery record",
        position: "0:00",
        length: "0:00",
        percent: 0,
        playing: false
    }'
}

if ! command -v playerctl >/dev/null 2>&1; then
    empty_json
    exit 0
fi

status="$(playerctl status 2>/dev/null || true)"
if [[ -z "$status" ]]; then
    empty_json
    exit 0
fi

artist="$(playerctl metadata artist 2>/dev/null || true)"
title="$(playerctl metadata title 2>/dev/null || true)"
album="$(playerctl metadata album 2>/dev/null || true)"
pos_s="$(playerctl position 2>/dev/null || printf '0')"
len_us="$(playerctl metadata mpris:length 2>/dev/null || printf '0')"

[[ -z "$title" ]] && title="untitled little song"
[[ -z "$artist" ]] && artist="unknown hand"
[[ -z "$album" ]] && album="a mystery record"

[[ "$pos_s" =~ ^[0-9]+([.][0-9]+)?$ ]] || pos_s=0
[[ "$len_us" =~ ^[0-9]+$ ]] || len_us=0

percent="$(awk -v p="$pos_s" -v l="$len_us" 'BEGIN {
    if (l > 0) {
        v = (p * 1000000 / l) * 100;
        if (v < 0) v = 0;
        if (v > 100) v = 100;
        printf "%d", v;
    } else {
        printf "0";
    }
}')"

format_time() {
    awk -v t="$1" 'BEGIN {
        t = int(t + 0.5);
        printf "%d:%02d", int(t / 60), t % 60;
    }'
}

position="$(format_time "$pos_s")"
length="$(format_time "$(awk -v l="$len_us" 'BEGIN { printf "%.3f", l / 1000000 }')")"

playing=false
[[ "$status" == "Playing" ]] && playing=true

jq -cn \
    --arg status "$status" \
    --arg artist "$artist" \
    --arg title "$title" \
    --arg album "$album" \
    --arg position "$position" \
    --arg length "$length" \
    --argjson percent "$percent" \
    --argjson playing "$playing" \
    '{status: $status, artist: $artist, title: $title, album: $album,
      position: $position, length: $length, percent: $percent, playing: $playing}'
