# App Store screenshots

1. Build and launch a **Debug** build with sample data (in-memory; never touches real links):
   `open -n <DerivedData>/Debug/LinkShelf.app --args -LinkShelfScreenshotDemo YES`
2. Set up a state in the popover, then capture it. The PNG goes to the clipboard, and the script saves it and restores your clipboard text:
   `Scripts/screenshots/grab.sh popover shot.png` (or `key` for a sheet window)
3. Compose a 2880×1800 image:
   `swiftc -O Scripts/screenshots/compose.swift -o /tmp/compose && /tmp/compose shot.png out.png $'Headline\nline two' "Subline" [sheet.png]`

Capture only works in screenshot-demo mode (see `LinkShelf/Debug/ScreenshotDemo.swift`), which is compiled out of Release builds.
