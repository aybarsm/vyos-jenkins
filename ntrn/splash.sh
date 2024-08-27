#!/usr/bin/env bash

set -e
source "$(dirname -- "$( readlink -f -- "$0"; )")/helper"

if ! command -v convert &> /dev/null; then
    consoleMsg "warning" "ImageMagick is missing. Installing..."
    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y imagemagick
    consoleMsg "success" "ImageMagick installed."
fi

TEXT="Sample Text"
FONT="Helvetica"
FONT_SIZE="12"
TEXT_COLOR="black"
X_ALIGN="left"
Y_ALIGN="top"
X_MARGIN=0
Y_MARGIN=0

while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--src)
      IMAGE_PATH="$2"
      shift 2
      ;;
    -t|--text)
      TEXT="$2"
      shift 2
      ;;
    -f|--font)
      FONT="$2"
      shift 2
      ;;
    -fs|--font-size)
      FONT_SIZE="$2"
      shift 2
      ;;
    -tc|--text-color)
      TEXT_COLOR="$2"
      shift 2
      ;;
    -d|--dst)
      DESTINATION_PATH="$2"
      shift 2
      ;;
    -x|--x-align)
      X_ALIGN="$2"
      shift 2
      ;;
    -y|--y-align)
      Y_ALIGN="$2"
      shift 2
      ;;
    -xm|--x-margin)
      X_MARGIN="$2"
      shift 2
      ;;
    -ym|--y-margin)
      Y_MARGIN="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if required parameters are provided
if [ -z "$IMAGE_PATH" ] || [ -z "$DESTINATION_PATH" ]; then
    echo "Usage: $0 -s|--src <source_image> -d|--dst <destination_image> [options]"
    echo "Options:"
    echo "  -t|--text <text>            (default: 'Sample Text')"
    echo "  -f|--font <font>            (default: Verdana)"
    echo "  -fs|--font-size <size>      (default: 12)"
    echo "  -tc|--text-color <color>    (default: black)"
    echo "  -x|--x-align <left|center|right>  (default: left)"
    echo "  -y|--y-align <top|middle|bottom> (default: top)"
    echo "  -xm|--x-margin <integer>         (default: 0)"
    echo "  -ym|--y-margin <integer>         (default: 0)"
    exit 1
fi

IMAGE_WIDTH=$(identify -format "%w" "$IMAGE_PATH")
IMAGE_HEIGHT=$(identify -format "%h" "$IMAGE_PATH")

TEXT_METRICS=$(convert -debug annotate xc: -font "$FONT" -pointsize "$FONT_SIZE" -annotate 0 "$TEXT" null: 2>&1 | grep Metrics:)
TEXT_WIDTH=$(str_between "$TEXT_METRICS" "width: " ";")
TEXT_HEIGHT=$(str_between "$TEXT_METRICS" "height: " ";")

case "$X_ALIGN" in
  left)
    TEXT_X=$X_MARGIN
    ;;
  center)
    TEXT_X=$(( ($IMAGE_WIDTH - $TEXT_WIDTH) / 2 + $X_MARGIN ))
    ;;
  right)
    TEXT_X=$(( $IMAGE_WIDTH - $TEXT_WIDTH - $X_MARGIN ))
    ;;
esac
echo "TEXT_X: $TEXT_X"

case "$Y_ALIGN" in
  top)
    TEXT_Y=$(( $TEXT_HEIGHT + $Y_MARGIN )) 
    ;;
  middle)
    TEXT_Y=$(( ($IMAGE_HEIGHT + $TEXT_HEIGHT) / 2 + $Y_MARGIN ))
    ;;
  bottom)
    TEXT_Y=$(( $IMAGE_HEIGHT - $Y_MARGIN ))
    ;;
esac
echo "TEXT_Y: $TEXT_Y"

TEXT_POSITION="+${TEXT_X}+${TEXT_Y}"

convert "$IMAGE_PATH" \
    -font "$FONT" \
    -pointsize "$FONT_SIZE" \
    -fill "$TEXT_COLOR" \
    -draw "text $TEXT_POSITION '$TEXT'" \
    "$DESTINATION_PATH"
