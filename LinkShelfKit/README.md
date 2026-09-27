# LinkShelfKit

The shared data layer that the multi-device plan proposes in
[`docs/REQUIREMENTS.md`](../docs/REQUIREMENTS.md) and
[`docs/FEATURE_SPECIFICATION.md`](../docs/FEATURE_SPECIFICATION.md).
It lives in this repository while it is a prototype, and it will move to its own repository once the device prototype has confirmed its design.

**Status:** package v0.x, not yet linked into the macOS app or the Share Extension. CloudKit sync is not enabled anywhere.

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

## Known gaps before Mac cutover

- There is no cross-process change signal yet. Apps still post and observe the existing Darwin notification and refetch on each one.
- Favicon cache service: the legacy plan exposes `favicons` for seeding, but the cache itself is app-owned and not written yet.
- `#Index` on `comparisonKey` and `uuid` requires macOS 15 / iOS 18; lookups currently use predicates without an index.
- Folder delete-versus-move and concurrent rank rebalance behavior under CloudKit are uncharacterized.
