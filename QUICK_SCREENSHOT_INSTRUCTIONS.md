# Quick Screenshot Instructions for App Store

## Step-by-Step Guide

### 1. Prepare Your App
- Run LinkShelf
- Add 3-5 sample links (e.g., LinkedIn, GitHub, Portfolio, Twitter, etc.)
- Make sure the links look good and are organized

### 2. Take Screenshots Using macOS Built-in Tool

**For 1440 x 900px screenshots (Recommended):**

1. **Open LinkShelf popover** by clicking the menu bar icon
2. **Press `Shift + Command + 4`** to enter screenshot mode
3. **Press `Spacebar`** - cursor changes to a camera icon
4. **Click on the LinkShelf popover window** - it will be highlighted
5. **Click to capture** - screenshot saved to Desktop
6. **Rename the file** to something like `LinkShelf_MainView.png`

### 3. Resize Screenshots (if needed)

**Using Preview (built-in macOS app):**
1. Open the screenshot in Preview
2. Go to **Tools → Adjust Size...**
3. Uncheck "Scale proportionally" if you need exact dimensions
4. Enter width: **1440** and height: **900** (or your target size)
5. Click **OK**
6. Save the file

**Or use command line:**
```bash
sips -z 900 1440 ~/Desktop/Screen*.png --out ~/Desktop/LinkShelf_1440x900.png
```

### 4. Recommended Screenshots to Take

**Screenshot 1: Main View (Essential)**
- Show popover with 3-5 links visible
- Show the header with "LinkShelf" and "+" button
- Make sure links look organized

**Screenshot 2: Adding a Link (Recommended)**
- Click the "+" button to open Add Link dialog
- Capture the form showing Title and URL fields

**Screenshot 3: Copy Feedback (Recommended)**
- Click copy on a link (shows checkmark)
- Capture the visual feedback

**Screenshot 4: Menu Bar Context (Optional)**
- Show the menu bar with LinkShelf icon
- Show popover open from menu bar
- Shows how it integrates with macOS

### 5. Create Multiple Resolutions

You can create all required sizes from one high-quality screenshot:

```bash
# Navigate to your screenshots folder
cd ~/Desktop

# Resize to different resolutions (using sips)
sips -z 800 1280 LinkShelf_MainView.png --out LinkShelf_1280x800.png
sips -z 900 1440 LinkShelf_MainView.png --out LinkShelf_1440x900.png
sips -z 1600 2560 LinkShelf_MainView.png --out LinkShelf_2560x1600.png
sips -z 1800 2880 LinkShelf_MainView.png --out LinkShelf_2880x1800.png
```

### 6. Tips

- **Use consistent backgrounds** - Keep the desktop/wallpaper the same
- **Show real data** - Use realistic link names and URLs
- **Highlight key features** - Make sure copy, add, and open buttons are visible
- **Keep it clean** - Remove any personal information or clutter
- **Test readability** - Make sure text is clear at all sizes

### 7. Upload to App Store Connect

Once you have your screenshots:
1. Go to App Store Connect
2. Navigate to your app → App Store → Screenshots
3. Drag and drop your screenshots (up to 10)
4. They will be automatically organized by resolution

