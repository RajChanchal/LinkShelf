# Localization Summary

## Languages Added

LinkShelf now supports **17 languages**:

1. **English (en)** - Base language
2. **Spanish (es)** - Español
3. **French (fr)** - Français
4. **German (de)** - Deutsch
5. **Japanese (ja)** - 日本語
6. **Chinese Simplified (zh-Hans)** - 简体中文
7. **Portuguese (pt)** - Português
8. **Italian (it)** - Italiano
9. **Russian (ru)** - Русский
10. **Korean (ko)** - 한국어
11. **Traditional Chinese (zh-Hant)** - 繁體中文
12. **Brazilian Portuguese (pt-BR)** - Português (Brasil)
13. **Dutch (nl)** - Nederlands
14. **Swedish (sv)** - Svenska
15. **Danish (da)** - Dansk
16. **Norwegian Bokmål (nb)** - Norsk Bokmål
17. **Finnish (fi)** - Suomi

## String Catalog

All translations live in the Xcode String Catalog:
```
LinkShelf/Resources/Localizable.xcstrings
```

## Implementation

- Xcode generates typed `LocalizedStringResource` symbols from manually
  managed catalog entries. Use them with `String(localized: .linkFolder)`;
  parameterized entries become generated functions such as
  `String(localized: .searchNoResultsMessage(query))`.
- The app and Share extension both package the same localized resources.
- Generated symbols preserve the catalog's parameter metadata, so callers do
  not need to manually format translated strings.
- Run `ruby Scripts/verify_localizations.rb` in CI to ensure every locale
  contains every English key.

## How to Add More Languages

1. Open `Localizable.xcstrings` in Xcode.
2. Add the language from the catalog inspector.
3. Translate the catalog entries.
4. Run `ruby Scripts/verify_localizations.rb`.

## Localized Strings

All strings are localized including:
- App name
- Empty states
- Search functionality
- Add/Edit link dialogs
- Buttons and actions
- Error messages
- Menu items
- Share Extension text
- Global shortcut tooltip and intro dialog

## Testing Localization

To test different languages:
1. Change the app language in Xcode’s scheme, or change the system language in
   macOS Settings.
2. Launch both the app and the Share extension.
3. Check long button labels and the no-results message as well as the main UI.
