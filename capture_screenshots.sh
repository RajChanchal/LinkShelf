#!/bin/bash

# LinkShelf Screenshot Capture Helper Script
# This script helps you capture screenshots at the correct App Store resolutions

echo "📸 LinkShelf Screenshot Capture Helper"
echo "======================================"
echo ""
echo "This script will help you capture screenshots for App Store submission."
echo ""
echo "Required resolutions:"
echo "  - 1280 x 800px"
echo "  - 1440 x 900px"
echo "  - 2560 x 1600px"
echo "  - 2880 x 1800px"
echo ""
echo "Instructions:"
echo "1. Make sure LinkShelf is running"
echo "2. Open the popover by clicking the menu bar icon"
echo "3. Position the popover where you want it"
echo "4. This script will guide you through capturing screenshots"
echo ""
read -p "Press Enter when you're ready to start..."

# Create screenshots directory
SCREENSHOT_DIR="$HOME/Desktop/LinkShelf_Screenshots"
mkdir -p "$SCREENSHOT_DIR"
echo "📁 Screenshots will be saved to: $SCREENSHOT_DIR"
echo ""

# Function to capture screenshot
capture_screenshot() {
    local name=$1
    local width=$2
    local height=$3
    
    echo "📸 Ready to capture: $name"
    echo "   Resolution: ${width}x${height}"
    echo ""
    echo "Instructions:"
    echo "  1. Press Shift+Command+4 to enter screenshot mode"
    echo "  2. Press Spacebar to switch to window capture"
    echo "  3. Click on the LinkShelf popover"
    echo "  4. The screenshot will be saved to your Desktop"
    echo ""
    read -p "Press Enter after you've taken the screenshot..."
    
    # Find the most recent screenshot
    LATEST_SCREENSHOT=$(ls -t ~/Desktop/Screen*.png 2>/dev/null | head -1)
    
    if [ -n "$LATEST_SCREENSHOT" ]; then
        # Copy and rename
        cp "$LATEST_SCREENSHOT" "$SCREENSHOT_DIR/${name}_${width}x${height}.png"
        echo "✅ Saved: ${name}_${width}x${height}.png"
        echo ""
    else
        echo "⚠️  No screenshot found. Please try again."
        echo ""
    fi
}

# Recommended screenshot sequence
echo "Let's capture the main screenshots:"
echo ""

# Main view
capture_screenshot "01_MainView" 1440 900

# Optional: Add more captures
read -p "Do you want to capture more screenshots? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Open the 'Add Link' dialog and press Enter when ready..."
    read -p ""
    capture_screenshot "02_AddLink" 1440 900
    
    echo "Show a link with copy feedback (checkmark) and press Enter when ready..."
    read -p ""
    capture_screenshot "03_CopyLink" 1440 900
fi

echo ""
echo "✨ Screenshot capture complete!"
echo "📁 All screenshots saved to: $SCREENSHOT_DIR"
echo ""
echo "Next steps:"
echo "1. Review the screenshots in the folder"
echo "2. Resize them if needed to match exact dimensions"
echo "3. Upload to App Store Connect"
echo ""

