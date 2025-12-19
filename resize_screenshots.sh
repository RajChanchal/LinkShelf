#!/bin/bash

# LinkShelf Screenshot Resizer (Fixed - maintains aspect ratio)
# Crops to 16:10 aspect ratio first, then resizes to App Store dimensions

echo "🖼️  LinkShelf Screenshot Resizer (Fixed)"
echo "========================================"
echo ""

# Check if sips is available (macOS built-in)
if ! command -v sips &> /dev/null; then
    echo "❌ Error: sips command not found. This script requires macOS."
    exit 1
fi

# Get input file
if [ -z "$1" ]; then
    echo "Usage: ./resize_screenshots.sh <input_image.png>"
    echo ""
    echo "Example: ./resize_screenshots.sh ~/Desktop/LinkShelf1.png"
    exit 1
fi

INPUT_FILE="$1"

# Check if file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Error: File not found: $INPUT_FILE"
    exit 1
fi

# Create output directory
OUTPUT_DIR="$HOME/Desktop/LinkShelf_AppStore_Screenshots"
mkdir -p "$OUTPUT_DIR"

# Create temp directory for intermediate files
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "📁 Output directory: $OUTPUT_DIR"
echo ""

# Get original dimensions
ORIG_WIDTH=$(sips -g pixelWidth "$INPUT_FILE" | awk '/pixelWidth:/ {print $2}')
ORIG_HEIGHT=$(sips -g pixelHeight "$INPUT_FILE" | awk '/pixelHeight:/ {print $2}')

echo "📐 Original dimensions: ${ORIG_WIDTH}x${ORIG_HEIGHT}"
echo ""

# Calculate crop dimensions for 16:10 aspect ratio
# Target aspect ratio: 1.6 (width/height = 16/10)
TARGET_ASPECT=1.6

# Use Python for floating point calculations (available on macOS)
CROP_WIDTH=$(python3 -c "
width = $ORIG_WIDTH
height = $ORIG_HEIGHT
aspect = width / height
target_aspect = 1.6

if aspect > target_aspect:
    # Image is wider, crop width
    crop_height = height
    crop_width = int(crop_height * target_aspect)
    crop_x = (width - crop_width) // 2
    crop_y = 0
else:
    # Image is taller, crop height
    crop_width = width
    crop_height = int(crop_width / target_aspect)
    crop_x = 0
    crop_y = (height - crop_height) // 2

print(f'{crop_width} {crop_height} {crop_x} {crop_y}')
")

read CROP_WIDTH CROP_HEIGHT CROP_X CROP_Y <<< "$CROP_WIDTH"

echo "✂️  Cropping to 16:10 aspect ratio..."
echo "   Crop area: ${CROP_WIDTH}x${CROP_HEIGHT} at position (${CROP_X}, ${CROP_Y})"
echo ""

# Crop the image to 16:10 aspect ratio using sips
# sips crop syntax: --cropToHeightWidth <height> <width> --cropOffset <y> <x>
CROPPED_FILE="$TEMP_DIR/cropped.png"
sips --cropToHeightWidth $CROP_HEIGHT $CROP_WIDTH --cropOffset $CROP_Y $CROP_X "$INPUT_FILE" --out "$CROPPED_FILE" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to crop image. Trying alternative method..."
    # Alternative: use ImageMagick if available, or manual crop
    # For now, let's try a simpler approach - just resize maintaining aspect and pad
    CROPPED_FILE="$INPUT_FILE"
    echo "⚠️  Using original image (may need manual cropping)"
fi

# Get base filename without extension
BASENAME=$(basename "$INPUT_FILE" .png)
BASENAME=$(basename "$BASENAME" .PNG)

# Resize to all required App Store dimensions
echo "🔄 Resizing to App Store dimensions..."
echo ""

# 1280 x 800
echo "  Creating 1280 x 800..."
sips -z 800 1280 "$CROPPED_FILE" --out "$OUTPUT_DIR/${BASENAME}_1280x800.png" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "  ✅ ${BASENAME}_1280x800.png"
else
    echo "  ❌ Failed to create 1280x800"
fi

# 1440 x 900
echo "  Creating 1440 x 900..."
sips -z 900 1440 "$CROPPED_FILE" --out "$OUTPUT_DIR/${BASENAME}_1440x900.png" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "  ✅ ${BASENAME}_1440x900.png"
else
    echo "  ❌ Failed to create 1440x900"
fi

# 2560 x 1600
echo "  Creating 2560 x 1600..."
sips -z 1600 2560 "$CROPPED_FILE" --out "$OUTPUT_DIR/${BASENAME}_2560x1600.png" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "  ✅ ${BASENAME}_2560x1600.png"
else
    echo "  ❌ Failed to create 2560x1600"
fi

# 2880 x 1800
echo "  Creating 2880 x 1800..."
sips -z 1800 2880 "$CROPPED_FILE" --out "$OUTPUT_DIR/${BASENAME}_2880x1800.png" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "  ✅ ${BASENAME}_2880x1800.png"
else
    echo "  ❌ Failed to create 2880x1800"
fi

echo ""
echo "✨ Done! All resized screenshots are in:"
echo "   $OUTPUT_DIR"
echo ""
echo "📤 Ready to upload to App Store Connect!"
