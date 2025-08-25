#!/usr/bin/env bash

# ------------ [ Output Folder and Input Link ] ------------

OUTPUT_DIR="/Your/Output/Folder/Path/Here"
mkdir -p "$OUTPUT_DIR"

URL="[Your Video/Playlist Link Here]"

# ---- Counters & Colors ----
TOTAL_VIDEOS=0
PROCESSED=0

BLUE="\e[34m"
GREEN="\e[32m"
RESET="\e[0m"

# ------------ [ Download & Processing ] ------------

download_and_process() {
    local url="$1"

    RAW_TITLE=$(yt-dlp --print "%(title)s" "$url")
    SANITIZED_TITLE=${RAW_TITLE//\//_}
    DIR="${OUTPUT_DIR}/${SANITIZED_TITLE}"
    mkdir -p "$DIR"

    echo -e "${GREEN}Processing Video...${RESET}"

    yt-dlp \
        -f "bestvideo+bestaudio/best" \
        --no-check-certificate \
        --quiet \
        --no-warnings \
        -o "${OUTPUT_DIR}/${SANITIZED_TITLE}/%(title)s.%(ext)s" \
        --write-thumbnail \
        --no-mtime \
        "$url" || true

    for vidfile in "$DIR"/*.{mp4,mkv,webm}; do
        [ -e "$vidfile" ] || continue
        base="${vidfile%.*}"
        ext="${vidfile##*.}"
        mv "$vidfile" "${base} - Re-Upload.${ext}"
    done

    for thumb in "$DIR"/*.jpg "$DIR"/*.webp; do
        [ -e "$thumb" ] || continue
        base="${thumb%.*}"
        ext="${thumb##*.}"
        mv "$thumb" "${base} - Thumbnail.${ext}"
    done

    # ------------ [ Gathering Information ] ------------
    
    TITLE=$RAW_TITLE
    INFO_JSON=$(yt-dlp --skip-download --no-warnings "$url" -j)
    UPLOAD_DATE=$(echo "$INFO_JSON" | jq -r .upload_date)
    CHANNEL_NAME=$(echo "$INFO_JSON" | jq -r '.uploader // .channel_title // "Unknown channel"')
    DESCRIPTION=$(echo "$INFO_JSON" | jq -r .description)

    if [[ -z "$DESCRIPTION" || "$DESCRIPTION" == "null" ]]; then
        DESCRIPTION="At the time of archive, this video did not have a description."
        HAS_DESC=0
    else
        HAS_DESC=1
    fi
    
    YEAR=${UPLOAD_DATE:0:4}
    MONTH_NUM=${UPLOAD_DATE:4:2}
    DAY=${UPLOAD_DATE:6:2}

    months=(January February March April May June July August September October November December)
    if [[ "$MONTH_NUM" =~ ^[0-9]{2}$ ]]; then
        month_index=$((10#$MONTH_NUM - 1))
    else
        month_index=0
    fi
    MONTH_NAME=${months[month_index]}

    DATE="${DAY} ${MONTH_NAME} ${YEAR}"
    BRIEF_DESC=$(echo "$DESCRIPTION" | head -n1 | tr -d '\r' | awk '{$1=$1;print}')

    # ------------ [ Creating the Text File ] ------------
    
    README_FILE="${DIR}/${TITLE} - Re-Upload Description.txt"
    README_CONTENT="This video was published on $DATE by $CHANNEL_NAME, [Short Description here]."
    if [[ $HAS_DESC -eq 1 ]]; then
        README_CONTENT+="

Original description as of the time of the archive:

$DESCRIPTION"
    else
        README_CONTENT+=$'\n\n'"$DESCRIPTION"
    fi
    echo "$README_CONTENT" >"$README_FILE"

    echo "✅ README written to: $README_FILE"

    # ---- Progress Reporting ----
    if [[ $TOTAL_VIDEOS -gt 0 ]]; then
        PROCESSED=$((PROCESSED + 1))
        echo -e "Progress: ${BLUE}${PROCESSED}${RESET} of ${BLUE}${TOTAL_VIDEOS}${RESET} videos processed."
    fi
}

# ------------ [ Execution Loop ] ------------

if [[ "$URL" == *"/playlist?"* || "$URL" == *"?list="* ]]; then
    mapfile -t VIDEO_IDS < <(yt-dlp --flat-playlist --get-id "$URL")
    TOTAL_VIDEOS=${#VIDEO_IDS[@]}
    PROCESSED=0
    for vid in "${VIDEO_IDS[@]}"; do
        FULL_URL="https://www.youtube.com/watch?v=$vid"
        download_and_process "$FULL_URL"
    done
else
    TOTAL_VIDEOS=1
    PROCESSED=0
    download_and_process "$URL"
fi
