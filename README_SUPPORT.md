# LinkShelf - Support & Documentation

**Version:** 1.0  
**Platform:** macOS 15.6 or later  
**Support:** [GitHub Issues](https://github.com/RajChanchal/LinkShelf/issues)

---

## Welcome to LinkShelf

LinkShelf is a minimal macOS menu bar application that helps you store and quickly access your frequently used links. With just one click, copy any link to your clipboard or open it in your browser.

---

## Getting Started

### First Launch

1. **Launch LinkShelf** - After installation, the app will appear in your menu bar (top-right area of your screen)
2. **Look for the link icon** (🔗) in your menu bar
3. **Click the icon** to open your link shelf
4. **Default links** - On first launch, you'll see example links (LinkedIn, GitHub, Portfolio) that you can edit or delete

### Basic Usage

#### Adding a Link
1. Click the **+** button in the top-right of the popover
2. Enter a **Title** (e.g., "My Portfolio")
3. Enter the **URL** (e.g., "https://example.com" or just "example.com")
4. Click **Add**

> **Tip:** You don't need to include "https://" - LinkShelf will add it automatically if missing.

#### Copying a Link
- Click the **copy icon** (📋) next to any link
- The link URL will be copied to your clipboard
- You'll see a green checkmark (✓) confirming the copy

#### Opening a Link
- Click the **open icon** (↗️) next to any link
- The link will open in your default web browser

#### Editing a Link
1. Click the **menu icon** (⋯) next to any link
2. Select **Edit**
3. Modify the title or URL
4. Click **Save**

#### Deleting a Link
1. Click the **menu icon** (⋯) next to any link
2. Select **Delete**
3. Confirm the deletion

#### Reordering Links
- **Drag and drop** links in the list to reorder them
- Your preferred order will be saved automatically

#### Quitting the App
- **Right-click** (or Control+click) the menu bar icon
- Select **Quit LinkShelf**
- Or click **Quit LinkShelf** at the bottom of the popover

---

## System Requirements

- **macOS:** 15.6 or later
- **Storage:** Minimal (less than 1 MB)
- **Internet:** Required only for opening links in browser

---

## Privacy & Data

### Data Storage
- All your links are stored **locally** on your Mac
- Data is saved using macOS UserDefaults (secure, local storage)
- **No data is sent to external servers**
- **No analytics or tracking**

### Permissions
LinkShelf requires minimal permissions:
- **Network access** - Only to open links in your browser
- **Clipboard access** - To copy links to your clipboard
- **No file system access** - All data is stored in app sandbox

### Your Privacy
- We don't collect any personal information
- We don't track your usage
- Your links remain private and local to your device

---

## Troubleshooting

### App Not Appearing in Menu Bar

**Issue:** Can't find the LinkShelf icon in the menu bar.

**Solutions:**
1. Check if the app is running:
   - Open **Activity Monitor**
   - Search for "LinkShelf"
   - If not running, launch the app from Applications
2. Check menu bar space:
   - Some menu bar items may be hidden
   - Look for a **>>** icon that shows hidden menu bar items
3. Restart the app:
   - Quit LinkShelf completely
   - Relaunch from Applications

### Links Not Saving

**Issue:** Added links disappear after closing the app.

**Solutions:**
1. Make sure you clicked **Add** (not just Cancel)
2. Check if the app has proper permissions:
   - Go to **System Settings** → **Privacy & Security**
   - Ensure LinkShelf has necessary permissions
3. Try restarting the app

### Copy Not Working

**Issue:** Clicking copy doesn't copy the link.

**Solutions:**
1. Check clipboard permissions:
   - macOS may ask for clipboard access on first use
   - Grant permission when prompted
2. Try copying again - sometimes the first attempt needs permission
3. Check if another app is interfering with clipboard access

### Links Not Opening in Browser

**Issue:** Clicking open doesn't launch the browser.

**Solutions:**
1. Check your default browser:
   - Go to **System Settings** → **Desktop & Dock** → **Default web browser**
  2. Verify the URL is valid:
   - Make sure the link has a proper URL format
   - Edit the link and ensure it starts with "http://" or "https://"
3. Check network connection:
   - Ensure you have an active internet connection

### Popover Not Showing

**Issue:** Clicking the menu bar icon doesn't open the popover.

**Solutions:**
1. Try clicking again - sometimes a single click is needed
2. Check if another window is blocking it
3. Restart the app
4. Check if the app is responding in Activity Monitor

---

## Frequently Asked Questions (FAQ)

### Q: Can I sync my links across devices?
**A:** Currently, LinkShelf stores links locally on your Mac. iCloud sync is a planned feature for future versions.

### Q: How many links can I store?
**A:** There's no hard limit, but for best performance, we recommend keeping it under 100 links.

### Q: Can I organize links into folders?
**A:** Folder organization is a planned feature. Currently, you can reorder links by dragging them.

### Q: Does LinkShelf work offline?
**A:** Yes! You can view, copy, and manage links offline. Only opening links in a browser requires internet.

### Q: Can I import links from another app?
**A:** Currently, links must be added manually. Import/export features are planned for future versions.

### Q: Is LinkShelf free?
**A:** Check the App Store listing for current pricing information.

### Q: Will LinkShelf work on older macOS versions?
**A:** LinkShelf requires macOS 15.6 or later. For older versions, please check the App Store for compatibility.

### Q: Can I customize the appearance?
**A:** LinkShelf uses the native macOS appearance (light/dark mode). The app automatically adapts to your system theme.

### Q: How do I report a bug?
**A:** Please report bugs on our [GitHub Issues page](https://github.com/RajChanchal/LinkShelf/issues).

### Q: Can I request a feature?
**A:** Yes! Feature requests are welcome on our [GitHub Issues page](https://github.com/RajChanchal/LinkShelf/issues).

---

## Keyboard Shortcuts

Currently, LinkShelf focuses on mouse/trackpad interaction. Keyboard shortcuts are planned for future versions.

---

## Known Issues

- None at this time. If you encounter any issues, please report them on [GitHub Issues](https://github.com/RajChanchal/LinkShelf/issues).

---

## Updates & Changelog

### Version 1.0 (Initial Release)
- Store and manage frequently used links
- One-click copy to clipboard
- Open links in default browser
- Add, edit, delete, and reorder links
- Native macOS menu bar integration
- Local, secure data storage

---

## Support & Contact

### Getting Help
- **Documentation:** This README file
- **Issues & Bugs:** [GitHub Issues](https://github.com/RajChanchal/LinkShelf/issues)
- **Feature Requests:** [GitHub Issues](https://github.com/RajChanchal/LinkShelf/issues)

### Reporting Issues
When reporting an issue, please include:
1. macOS version
2. LinkShelf version
3. Steps to reproduce the issue
4. Expected behavior vs. actual behavior
5. Screenshots (if applicable)

---

## License

LinkShelf is available on the Mac App Store. Please refer to the App Store listing for license terms.

---

## Acknowledgments

Built with SwiftUI and AppKit for macOS.  
Icon uses SF Symbols.

---

**Last Updated:** December 2024  
**Repository:** [github.com/RajChanchal/LinkShelf](https://github.com/RajChanchal/LinkShelf)

