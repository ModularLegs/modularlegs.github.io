#!/usr/bin/env bash
# Generate video thumbnails, compressed previews, and videos.json manifest.
# Usage: bash scripts/generate_video_previews.sh
# Requires: ffmpeg

set -euo pipefail
cd "$(dirname "$0")/.."

VIDEO_DIR="videos"
THUMB_DIR="videos/thumbnails"
PREVIEW_DIR="videos/previews"
MANIFEST="videos.json"

SUBDIRS=("single_modules" "evo3" "evo4" "evo5" "quad")

# Preview settings
PREVIEW_WIDTH=480        # px (height auto)
PREVIEW_MAX_DURATION=5   # seconds
PREVIEW_BITRATE="500k"
THUMB_WIDTH=640          # px

echo "=== Video preview generator ==="

# Create output dirs
for sub in "${SUBDIRS[@]}"; do
    mkdir -p "$THUMB_DIR/$sub" "$PREVIEW_DIR/$sub"
done

# Start JSON array
json="["
first=true

for sub in "${SUBDIRS[@]}"; do
    dir="$VIDEO_DIR/$sub"
    [ -d "$dir" ] || continue

    for video in "$dir"/*.mp4; do
        [ -f "$video" ] || continue

        filename="$(basename "$video")"
        name="${filename%.mp4}"

        thumb_path="$THUMB_DIR/$sub/${name}.jpg"
        preview_path="$PREVIEW_DIR/$sub/${name}.mp4"
        video_path="$video"

        # --- Thumbnail (skip if exists) ---
        if [ ! -f "$thumb_path" ]; then
            echo "  [thumb] $video_path -> $thumb_path"
            ffmpeg -y -ss 1 -i "$video" \
                -vframes 1 -vf "scale=${THUMB_WIDTH}:-2" \
                -q:v 3 "$thumb_path" \
                -loglevel error 2>&1 || \
            # Fallback to frame 0 if video < 1s
            ffmpeg -y -i "$video" \
                -vframes 1 -vf "scale=${THUMB_WIDTH}:-2" \
                -q:v 3 "$thumb_path" \
                -loglevel error 2>&1
        else
            echo "  [skip]  $thumb_path (exists)"
        fi

        # --- Preview clip (skip if exists) ---
        if [ ! -f "$preview_path" ]; then
            echo "  [prev]  $video_path -> $preview_path"
            ffmpeg -y -i "$video" \
                -t "$PREVIEW_MAX_DURATION" \
                -vf "scale=${PREVIEW_WIDTH}:-2" \
                -c:v libx264 -preset fast -crf 28 \
                -b:v "$PREVIEW_BITRATE" -maxrate "$PREVIEW_BITRATE" -bufsize 1M \
                -an -movflags +faststart \
                "$preview_path" \
                -loglevel error 2>&1
        else
            echo "  [skip]  $preview_path (exists)"
        fi

        # --- Add to JSON ---
        if [ "$first" = true ]; then
            first=false
        else
            json+=","
        fi
        json+="
  {
    \"filename\": \"${filename}\",
    \"subdir\": \"${sub}\",
    \"preview_path\": \"${preview_path}\",
    \"thumbnail_path\": \"${thumb_path}\",
    \"youtube_url\": \"https://www.youtube.com/embed/PLACEHOLDER\",
    \"drive_url\": \"https://drive.google.com/file/d/PLACEHOLDER/view\"
  }"
    done
done

json+="
]"

echo "$json" > "$MANIFEST"
echo ""
echo "=== Done! ==="
echo "  Thumbnails:  $THUMB_DIR/"
echo "  Previews:    $PREVIEW_DIR/"
echo "  Manifest:    $MANIFEST"
echo "  Total items: $(echo "$json" | grep -c '"filename"')"
