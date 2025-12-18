# Better Screenshot Guide for App Store

## The Problem
Your current screenshots are portrait-oriented (taller than wide), but App Store requires 16:10 landscape format. This causes cropping issues.

## Solution: Take Landscape Screenshots

### Option 1: Capture Menu Bar + Popover Together (Recommended)
This shows the app in context and naturally creates a landscape image:

1. **Position your screen/window:**
   - Make sure your desktop is visible
   - Open LinkShelf popover
   - Position it so you can see:
     - The menu bar with LinkShelf icon
     - The popover below it
     - Some desktop background

2. **Take screenshot:**
   - Press `Shift + Command + 4`
   - Drag to select a wide area that includes:
     - Top: Menu bar with LinkShelf icon
     - Middle: The popover with links
     - Sides: Some desktop background
   - This creates a landscape-oriented screenshot

### Option 2: Use a Wider Popover Area
1. Open LinkShelf popover
2. Make sure you have 4-5 links visible (not just 2)
3. Take screenshot of a wider area that includes:
   - The full popover width
   - Some space on left/right sides
   - This creates a more landscape-oriented capture

### Option 3: Use the Padded Script
If you want to keep your current screenshots, use the padded version:
```bash
python3 resize_screenshots_padded.py ~/Desktop/LinkShelf1.png
```

This preserves all content but adds dark padding on the sides.

## Recommended Screenshot Compositions

### Screenshot 1: Main View with Context
- Show menu bar icon
- Show popover with 4-5 links
- Some desktop background visible
- Landscape orientation

### Screenshot 2: Close-up of Popover
- Full popover with all UI elements visible
- 4-5 links showing
- Landscape crop that doesn't cut off top/bottom

### Screenshot 3: Adding a Link
- Show the "Add Link" dialog
- Can be more square/portrait
- Will be padded to fit 16:10

## Quick Fix for Current Screenshots

If you want to use your current screenshots, run:
```bash
# Process all three with padding (preserves all content)
python3 resize_screenshots_padded.py ~/Desktop/LinkShelf1.png
python3 resize_screenshots_padded.py ~/Desktop/LinkShelf2.png
python3 resize_screenshots_padded.py ~/Desktop/LinkShelf3.png
```

This will preserve all UI elements but may have dark bars on the sides.

