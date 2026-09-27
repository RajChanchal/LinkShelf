# LinkShelf Agent Guidelines

## Project scope

LinkShelf is a macOS menu bar application targeting macOS 14+. It uses SwiftUI for views, AppKit for menu bar and global shortcut integration, and a Share Extension for adding links from other apps.

Before changing behavior, understand whether the change affects the main app, the Share Extension, or their shared app-group storage.

## Architecture and ownership

- `LinkShelfApp.swift` owns app lifecycle, menu-bar activation policy, global shortcut registration, and settings state.
- `StatusBarController` owns the AppKit status-bar item and popover presentation.
- `LinkListView` and `AddEditLinkView` are SwiftUI presentation layers. Keep business logic out of views when it can live in `LinkManager`.
- `LinkManager` is the observable application-facing model. It maps views' `Link` values and folder paths onto `LinkRepository` operations, and it coordinates favicon loading and cross-process refresh.
- The in-repo `LinkShelfKit` package owns domain rules (`LinkShelfDomain`) and persistence (`LinkShelfPersistence`): the SwiftData schema, `LinkRepository`, legacy UserDefaults migration, and `LinkShelfAppGroupStorage`. Keep schema, validation, ordering, and app-group storage details behind this boundary.
- `LinkShelfShare/ShareViewController.swift` is the Share Extension entry point. It must open the store through `LinkShelfAppGroupStorage` and must not write while the legacy migration is pending.
- Favicons live in the app's local `FaviconCache`, never in link records.
- Prefer small, testable types and dependency injection through protocols or initializer parameters when adding new services.

Do not introduce a second persistence path, duplicate link sorting or URL validation rules, or direct `UserDefaults` access from views without a clear reason. Settings remain in `UserDefaults`/`@AppStorage`.

## Localization

- The source of truth is `LinkShelf/Resources/Localizable.xcstrings`.
- Use Swift generated localization symbols where available; otherwise use `String(localized:)` or localized SwiftUI APIs.
- Never add user-visible text as an untranslated string literal.
- Preserve localization keys and placeholders when editing existing translations.
- When adding a key, update the String Catalog and verify all supported locales remain valid.
- Do not recreate the removed `.lproj/Localizable.strings` files or reintroduce the old localization helper.

## Swift and macOS practices

- Preserve SwiftUI state ownership: use `@State` for local view state, `@Binding` for parent-owned state, and `@AppStorage` only for settings backed by UserDefaults.
- Keep UI updates on the main actor/main queue. Perform favicon/network work asynchronously and avoid blocking the menu-bar UI.
- Treat URLs and user-provided strings as untrusted input; validate them before opening or persisting when appropriate.
- Preserve App Sandbox, entitlements, app-group identifiers, and Share Extension behavior unless the task explicitly changes them.
- Avoid force unwraps and force casts. If an existing API requires them, isolate and document the boundary.

## Linting and validation

The lint configuration is `.swiftlint.yml`. It is run strictly from the Xcode `SwiftLint` build phase:

```sh
swiftlint lint --strict --quiet --no-cache
```

Run these checks after Swift changes:

```sh
swiftlint lint --strict --quiet --no-cache
git diff --check
xcodebuild -project LinkShelf.xcodeproj -list
(cd LinkShelfKit && swift test)
```

When building locally, use a writable DerivedData directory if the default Xcode location is unavailable:

```sh
xcodebuild -project LinkShelf.xcodeproj \
  -scheme LinkShelf \
  -configuration Debug \
  -destination 'generic/platform=macOS' \
  -derivedDataPath /tmp/LinkShelf-DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

Business rules and persistence are tested in `LinkShelfKit` with Swift Testing. The app targets have no unit-test target; put new logic in the package when it can be tested there.

## Change discipline

- Make the smallest change that satisfies the task; avoid unrelated formatting or architecture rewrites.
- Keep generated Xcode project changes intentional and reviewable.
- Update user-facing documentation when behavior, settings, release behavior, or supported platforms change.
- Do not commit secrets, provisioning profiles, local DerivedData, or machine-specific settings.
- Before handing work back, check `git status`, review the diff, and report any validation blocked by the local environment.

## Git and pull requests

- Work on a dedicated `codex/` branch unless the user specifies another branch.
- Use focused commits with descriptive messages.
- PR descriptions should summarize behavior changes, validation performed, and known environment limitations.
- Xcode Cloud workflow trigger settings are managed in App Store Connect; the repository manifest does not control whether builds start automatically.
