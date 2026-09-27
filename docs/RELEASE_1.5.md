# LinkShelf 1.5 release checklist

1.5 moves storage from UserDefaults to SwiftData (`LinkShelfKit`) and raises the minimum to macOS 14. It does **not** include iCloud sync.

## Before archiving

- [ ] [RajChanchal/LinkShelf#12](https://github.com/RajChanchal/LinkShelf/pull/12) (storage migration) and the 1.5 release-prep branch are merged to `main`.
- [ ] Version is 1.5 (build 8) for both the app and the Share Extension.
- [ ] `(cd LinkShelfKit && swift test)`, `swiftlint lint --strict --quiet --no-cache`, and `ruby Scripts/verify_localizations.rb` pass.
- [ ] The privacy policy update is reviewed. Merging to `main` republishes <https://rajchanchal.github.io/LinkShelf/> from `index.html`; confirm the live page shows "Last Updated: September 2026".

## TestFlight upgrade tests

Install the App Store 1.4 build first, then upgrade to the 1.5 TestFlight build. Use real, non-trivial data: nested folders, empty folders, reordered links, and links with icons.

| Scenario | Expected |
| --- | --- |
| Upgrade 1.4 → 1.5 with an existing collection | All links, folders (including empty and nested ones) and per-folder order appear. There is no empty-state flash; a spinner shows until loading finishes. |
| Relaunch 1.5 | Same collection, nothing duplicated, no migration repeat. |
| Quit 1.5 during the first launch, then relaunch | Migration resumes or completes and nothing is duplicated. |
| Share Extension used before first opening 1.5 | The extension asks you to open LinkShelf first and saves nothing. After opening the app, sharing works. |
| Share from Safari while the app is running | Link saves, the sheet closes, and the link appears in the popover. |
| Fresh install (no 1.4 data) | Empty state with onboarding; nothing is seeded. |
| Add, edit, delete + undo, reorder, folder create/rename/move/delete, bookmark import | Behaves as in 1.4 and persists across relaunch. |
| Favicons on and off | With icons on, icons fill in; with them off, cached icons show and nothing is fetched. |
| VoiceOver and keyboard navigation in the popover | Unchanged from 1.4. |
| Non-English locale (e.g. German, Japanese) | New error and extension messages appear translated. |

## App Store Connect

- [ ] Paste the per-locale notes from `APP_STORE_WHATS_NEW.md`.
- [ ] Customers on macOS 11–13 stay on 1.4; the App Store handles this from the new minimum version. Mention it in support replies if asked.
- [ ] The App Privacy answers are unchanged: no data is collected.

## After release

- Do not install a 1.4 build over 1.5. 1.4 reads only the legacy storage, so links added in 1.5 would not appear there, and changes made in 1.4 are never imported again.
- The original 1.4 data and a backup copy stay in the App Group container. See the privacy policy's Data Retention section.
