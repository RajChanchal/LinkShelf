# Share Extension Setup Guide

This guide explains how to configure the Share Extension target in Xcode after the code files have been created.

## Prerequisites

All Share Extension files have been created:
- `LinkShelfShare/ShareViewController.swift`
- `LinkShelfShare/Info.plist`
- `LinkShelfShare/LinkShelfShare.entitlements`

## Steps to Configure in Xcode

### 1. Add Share Extension Target

1. Open `LinkShelf.xcodeproj` in Xcode
2. Click on the project in the navigator (top item)
3. Click the **+** button at the bottom of the TARGETS list
4. Select **macOS** → **App Extension** → **Share Extension**
5. Click **Next**
6. Configure:
   - **Product Name**: `LinkShelfShare`
   - **Bundle Identifier**: `com.chanchalgeek.LinkShelf.ShareExtension`
   - **Language**: Swift
7. Click **Finish**

### 2. Remove Default Files

1. Delete the default `ShareViewController.swift` that Xcode created (if any)
2. Delete the default `Info.plist` that Xcode created (if any)
3. Keep only the files we created in `LinkShelfShare/`

### 3. Add Files to Share Extension Target

1. In Xcode, select the following files and add them to the Share Extension target:
   - `LinkShelfShare/ShareViewController.swift` → Check "LinkShelfShare" target
   - `LinkShelfShare/Info.plist` → Check "LinkShelfShare" target
   - `LinkShelfShare/LinkShelfShare.entitlements` → Check "LinkShelfShare" target
   - `LinkShelf/Models/Link.swift` → Check "LinkShelfShare" target (needed by SharedLinkStorage)
   - `LinkShelf/Stores/LinkStore.swift` → Check "LinkShelfShare" target (shared storage)
   - `LinkShelf/Managers/SharedLinkStorage.swift` → Check "LinkShelfShare" target

### 4. Add Localization Files to Share Extension

1. Add all `Localizable.strings` files to the Share Extension target:
   - Select each `Localizable.strings` file in `LinkShelf/Resources/{lang}.lproj/`
   - In File Inspector, check "LinkShelfShare" under Target Membership

### 5. Configure Build Settings

1. Select the **LinkShelfShare** target
2. Go to **Build Settings**
3. Set the following:
   - **Product Bundle Identifier**: `com.chanchalgeek.LinkShelf.ShareExtension`
   - **Info.plist File**: `LinkShelfShare/Info.plist`
   - **Code Signing Entitlements**: `LinkShelfShare/LinkShelfShare.entitlements`
   - **Deployment Target**: Same as main app (macOS 11.0+)

### 6. Configure Capabilities

1. Select the **LinkShelfShare** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **App Groups**
5. Enable the group: `group.com.chanchalgeek.LinkShelf`
6. Ensure it matches the main app's App Group

### 7. Configure Info.plist

Verify that `LinkShelfShare/Info.plist` has the correct settings:
- `NSExtensionPointIdentifier`: `com.apple.share-services`
- `NSExtensionPrincipalClass`: `$(PRODUCT_MODULE_NAME).ShareViewController`
- Activation rules for URLs and text

### 8. Build and Test

1. Build the project (⌘B)
2. Run the main app (⌘R)
3. Test sharing:
   - Open Safari
   - Navigate to any website
   - Click Share button
   - Select "LinkShelf" from the share menu
   - Verify the Share Extension opens with URL and title
   - Test adding a link
   - Verify it appears in the main app

## Troubleshooting

### Share Extension Not Appearing in Share Menu

1. Check that the extension is properly signed
2. Verify App Groups match between main app and extension
3. Restart the Mac (extensions are cached)
4. Check Console.app for error messages

### "Cannot find 'Link' in scope"

- Ensure `Link.swift` is added to the Share Extension target
- Clean build folder (⌘ShiftK) and rebuild

### "Cannot find 'SharedLinkStorage' in scope"

- Ensure `SharedLinkStorage.swift` is added to the Share Extension target
- Clean build folder and rebuild

### Localization Not Working

- Ensure all `Localizable.strings` files are added to the Share Extension target
- Check that the extension's bundle includes the localization files

### App Group Not Working

- Verify both main app and extension have the same App Group ID
- Check entitlements files match
- Ensure UserDefaults(suiteName:) uses the exact same string

## Notes

- The Share Extension runs in a separate process from the main app
- Data sharing is done via App Group UserDefaults
- The extension UI uses AppKit (not SwiftUI)
- The extension automatically closes after saving a link



