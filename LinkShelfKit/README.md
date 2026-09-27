# LinkShelfKit

The shared data layer that the multi-device plan proposes in
[`docs/REQUIREMENTS.md`](../docs/REQUIREMENTS.md) and
[`docs/FEATURE_SPECIFICATION.md`](../docs/FEATURE_SPECIFICATION.md).
It lives in this repository while it is a prototype, and it will move to its own repository once the device prototype has confirmed its design.

**Status:** package v0.x, linked into the macOS app and its Share Extension through a local package reference. Both use a local-only store in the App Group container. CloudKit sync is not enabled anywhere.

## Products

| Target | Contents |
| --- | --- |
| `LinkShelfDomain` | Foundation only. URL validation and comparison keys (FR-02), `LinkDraft` validation, `Sendable` snapshots, sparse ranks (FR-04), `FolderTree` cycle detection and repair (FR-03), deterministic duplicate reconciliation (FR-09), and the legacy UserDefaults import planner and backup (FR-10). Errors are returned as the typed `LinkShelfError`; the package produces no user-facing text. |
| `LinkShelfPersistence` | SwiftData `LinkShelfSchemaV1` (CloudKit-compatible: defaults on every attribute, optional relationships with inverses, no unique constraints), `LinkShelfMigrationPlan`, `LinkShelfContainerFactory` (in-memory, file, or App Group; local-only or a CloudKit private database), the `LinkRepository` model actor, and the resumable legacy migration with a file-based checkpoint. |

Minimum platforms are macOS 14 and iOS 17, as the requirements propose. The Xcode project's deployment settings are unchanged until that decision is confirmed.

## Validation

```sh
cd LinkShelfKit && swift test
```

Tests use in-memory or temporary on-disk stores only. Anything involving CloudKit, App Group access, or cross-process behavior still needs the real-device prototype described in the requirements, step 1.

## Known gaps

- `LinkShelfChangeSignal` is a Darwin-notification hint, not a durable change ledger. Observers refetch through a fresh `LinkRepository` context when they receive it.
- `#Index` on `comparisonKey` and `uuid` requires macOS 15 / iOS 18; lookups currently use predicates without an index.
- Folder delete-versus-move and concurrent rank rebalance behavior under CloudKit are uncharacterized.
