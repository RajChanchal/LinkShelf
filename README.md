# LinkShelf

A minimal macOS menu bar app for storing and quickly copying frequently used links.

## Features

- 🎯 **One-click copy** - Copy any link to clipboard instantly
- 📋 **Visual feedback** - See a checkmark when link is copied
- 🌐 **Open in browser** - Optional secondary action to open links
- ✏️ **Full management** - Add, edit, delete, and reorder links
- 🗂️ **Folders** - Group links into folders (optional)
- 💾 **Local storage** - All data stored securely on your Mac
- 🎨 **Native macOS UI** - Beautiful, minimal interface
- 🧭 **Global shortcut** - Press ⌥⌘L to open LinkShelf from anywhere
- 📤 **Share Extension** - Add links directly from Safari and other apps
- 🚀 **Fast & lightweight** - No bloat, just works

## Setup Instructions

### Option 1: Create Xcode Project (Recommended)

1. Open Xcode
2. Create a new project:
   - Choose **macOS** → **App**
   - Product Name: `LinkShelf`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Use Core Data" and "Include Tests" (optional)

3. Replace the default files with the files from this repository:
   - Copy all files from `LinkShelf/` folder to your Xcode project
   - Make sure the folder structure matches:
     ```
     LinkShelf/
     ├── LinkShelfApp.swift
     ├── Models/
     │   └── Link.swift
     ├── Managers/
     │   └── LinkManager.swift
     ├── Controllers/
     │   └── StatusBarController.swift
     └── Views/
         ├── LinkListView.swift
         └── AddEditLinkView.swift
     ```

4. Configure the app:
   - In Xcode, select your project in the navigator
   - Go to **Signing & Capabilities**
   - Ensure **App Sandbox** is enabled (or disable it if you prefer)
   - Set **Application Category** to "Utility" or "Productivity"

5. Build and run:
   - Press `⌘R` to build and run
   - The app will appear in your menu bar

### Option 2: Using Swift Package Manager

This project can also be set up as a Swift Package, though for a macOS app, Xcode project is recommended.

## Usage

1. **First Launch**: The app will show example links (LinkedIn, GitHub, Portfolio)
2. **Add Links**: Click the `+` button to add your own links
3. **Copy Links**: Click the copy icon (📋) next to any link
4. **Open Links**: Click the open icon (↗️) to open in your default browser
5. **Edit/Delete**: Click the menu (⋯) button to edit or delete links
6. **Reorder**: Drag links in the list to reorder them
7. **Open instantly**: Press `⌥ + ⌘ + L` to open LinkShelf without touching the mouse
8. **Add from other apps**: Use the “LinkShelf” option in the macOS share menu (Safari and any app that supports sharing)
9. **Rename a folder**: Right-click its header and choose “Rename folder…”. Renaming also updates nested folder paths; names that collide with another folder cannot be saved.
10. **Delete a folder**: Right-click its header and choose “Delete folder…”. Confirm to permanently delete its bookmarks and all nested folders.
11. **Create folders**: Use “New folder…” in the main menu, or right-click a folder and choose “New subfolder…”. Empty folders are saved. Nested folders appear indented; collapse a parent to hide its descendants.
9. **Organize**: Add an optional folder name when creating or editing a link

## Default Links

On first launch, LinkShelf includes these example links:
- LinkedIn Profile
- GitHub Profile
- Portfolio Website

You can edit or delete these to customize your shelf.

## Technical Details

- **Platform**: macOS 11.0+
- **Framework**: SwiftUI + AppKit
- **Storage**: UserDefaults (local, secure)
- **Architecture**: MVVM pattern
- **Shortcut**: Press ⌥⌘L to open LinkShelf from anywhere

## Future Enhancements (Not in MVP)

- ⌘+Number keyboard shortcuts
- iCloud sync
- Custom icons per link

## License

Created for personal use. Feel free to modify and use as needed.
