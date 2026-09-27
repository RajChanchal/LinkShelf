# LinkShelf feature and architecture specification

Status: proposed implementation design, not a description of shipped functionality. An in-repo prototype of the package lives in [`LinkShelfKit/`](../LinkShelfKit/README.md); its README lists what is implemented and the known gaps.
Date: 2026-09-27.
Requirements: [Multi-device requirements](REQUIREMENTS.md).

## Shared package and repository pattern

Create a dedicated `LinkShelfKit` Swift package repository and consume tagged semantic versions from the macOS and iOS repositories. Separate repos fit independent app release schedules; the package is the single source of truth for schema and business rules. Local path dependencies may be used during coordinated development, but release builds resolve committed package versions and lockfiles. Initial prototyping may keep the package in this repository before extraction.

Suggested package layout:

```text
LinkShelfKit/
  Package.swift
  Sources/
    LinkShelfDomain/        # Value snapshots, IDs, URL rules, commands, errors
    LinkShelfPersistence/   # SwiftData models, schema versions, migration,
                           # container factory, repository, change observation
  Tests/
    LinkShelfDomainTests/
    LinkShelfPersistenceTests/
```

Both products target macOS 14 and iOS 17 initially. The domain target uses Foundation and contains no platform UI imports. Persistence depends on the domain target and SwiftData. Do not place AppKit/UIKit UI, signing configuration, entitlements, or secrets in the package. Package version and database schema version are separate concepts.

Apps inject storage configuration, preferences, favicon services, and platform actions. Apps own CloudKit/App Group entitlements, notifications/background capabilities, provisioning, and localized presentation. The package returns typed errors rather than English UI strings.

## Data ownership and API

Keep `LinkManager` as the macOS-facing observable adapter initially. An iOS view model consumes the same repository operations. Views edit value drafts and submit validated commands; they do not insert partially completed persistent models or access UserDefaults directly.

Repository contract includes fetch/search with limits, fetch by UUID, insert/update/delete link, move/reorder, folder create/rename/delete, explicit save error reporting, and an observable change stream. Replace the current `saveLinks([Link])` collection overwrite API. Fetch/save failures must be distinguishable from an empty collection.

Provide immutable, `Sendable` snapshots at concurrency boundaries. Persistent model objects and `ModelContext` instances remain confined to their owning actor/context. Use a repository actor or `ModelActor` for background persistence and return snapshots to UI adapters on the main actor. Do not share managed objects across processes or tasks.

Settings remain in a separate preferences abstraction. Favicons live in an injected cache service with bounded size, eviction, timeout, and failure handling. The same URL normalization and folder-ordering implementations serve both apps and extensions.

## Versioned model

Start with a `VersionedSchema` and `SchemaMigrationPlan` even for schema version 1. CloudKit-compatible persisted attributes have suitable defaults or are optional; relationships are optional and have explicit inverses. Validate all models against Apple's requirements. Do not use `@Attribute(.unique)`, `#Unique`, or deny delete rules in synced models.

| Record | Proposed fields | Notes |
| --- | --- | --- |
| LinkRecord | UUID, title, URL string, comparison key, rank, createdAt, updatedAt, optional folder relationship | Preserve legacy UUIDs. Application validation enforces complete title/URL; model defaults only satisfy storage compatibility. |
| FolderRecord | UUID, name, rank, createdAt, updatedAt, optional parent/children and links relationships | Stable identity supports rename; tolerate temporarily missing relationships during sync. |
| Migration checkpoint | Migration version, verified source fingerprint, completed batches/status | Local metadata, excluded from the synced schema; use durable state owned by persistence. |

The comparison key is derived from the validated URL and is not a globally unique database constraint. Folder display paths are derived from relationships; do not make names or paths the identity. Define optionality, defaults, indexes, and delete rules explicitly in the implementation review.

## Storage and CloudKit configuration

Use a named `ModelConfiguration` with an explicit App Group location and explicit CloudKit private container selection. Keep stable schema/entity names, configuration name, and local store location across releases. Both applications use the same CloudKit container identifier and compatible schema. Each host and its extensions use the same local store path on that device.

The existing Mac App Group is `group.com.chanchalgeek.LinkShelf`. A candidate CloudKit identifier is `iCloud.com.chanchalgeek.LinkShelf`; its actual registration must be verified. iOS App Group provisioning must be verified independently; the cross-device invariant is the CloudKit container/schema, not identical local file paths.

The host app owns the primary sync lifecycle. Extensions prioritize short local transactions; prototype a local-only CloudKit configuration against the shared store and verify that host synchronization exports extension-created changes. Do not assume identical concurrent sync configuration is safe without device testing. The extension reports success only after `ModelContext.save()` succeeds and then completes its request.

Package configuration must support persistent local stores for development, CloudKit-enabled stores for device tests, and in-memory/local-only stores for automated tests. Tests must never use the shipping user's database.

## Features and behavior

### Link management and URL safety — FR-01, FR-02, FR-09

Trim surrounding whitespace, add HTTPS for inputs without a scheme, and validate HTTP(S) scheme plus host. Reject embedded credentials for newly added links, and require a nonempty trimmed title. Preserve path/query case, fragments, and other meaningful URL components. Comparison canonicalizes scheme/host and default ports only; further equivalences require explicit tests and a product decision.

Check duplicates locally before insert. Concurrent additions can still produce duplicates because CloudKit does not enforce unique constraints. Reconcile only exact semantic duplicates automatically, choosing the lowest UUID lexical value as the stable survivor. Retain divergent titles/folder choices as separate records with a review prompt; do not silently erase them. UUID collisions from interrupted import require the same explicit reconciliation rules. Reconciliation must be idempotent across repeated imports.

Opening a link revalidates its stored value, including values received through migration/sync. Historic invalid values are retained for correction and cannot be opened. Editing a URL uses the same validation as creation.

### Folders, ordering, and concurrent changes — FR-03, FR-04

Represent nesting through folder relationships and prevent cycles locally. Apply deterministic repair to remotely introduced cycles, preserving all links and surfacing a recovery notice. Missing relationships temporarily show records under an unfiled/recovering view rather than hiding them.

Use sparse integer ranks within each folder, with UUID as a deterministic tie-breaker. Reordering updates only affected records when space permits; bounded rebalance handles exhausted gaps. Persist logical moves through repository commands. Prototype concurrent rebalances; adopt a different rank scheme before release if this approach fails convergence tests.

Renaming keeps folder identity. Folder deletion requires confirmation and deletes descendants and contained links, matching current Mac behavior. CloudKit relationship changes are not atomic: prototype delete-versus-move/edit behavior and determine whether explicit tombstones or an operation model are needed. Do not claim an atomic recursive cloud delete. Define and document observed resolution behavior before FR-03 is accepted.

Independent edits should survive where managed sync supports them. Characterize same-field conflicts, delete-versus-edit, and moves on real devices; timestamps alone cannot enforce conflict policy. If default managed behavior loses unacceptable user edits, revise the data model or add recoverable revisions before release.

### Native applications — FR-04, FR-13

Mac retains its menu bar popover, global shortcut, keyboard navigation, existing management flows, and bookmark import. iPhone offers a searchable link list, folder navigation, add/edit forms, copy feedback, open-in-browser action, system sharing, reorder/move actions, and settings. iOS does not emulate Mac global shortcuts or menu bar behavior.

Both apps distinguish local loading, loaded empty collection, possible incoming sync data, and failed load. First launch remains free of seeded sample links. Search operates on local records and remains available offline.

### Share Extensions and refresh — FR-05

Accept URL/plain-text share input and editable titles. Validate through the package and show duplicate feedback before save when locally detectable. Failed validation/save keeps the form available for retry.

Each process owns its own context. Refetch relevant views after external changes and app activation; a Darwin notification can prompt a refresh but is not a durable change ledger. Do not rely solely on SwiftUI `@Query` to observe writes from another process.

SwiftData public history APIs require newer OS versions than the baseline; availability-gate their use. At the minimum OS versions, prototype supported change notification/refetch behavior and reopening contexts as needed. Do not blindly copy Core Data history code into SwiftData or enable undocumented coordinator access. Raise minimum OS versions only through an explicit product decision if reliable extension refresh cannot be achieved.

### Sync experience and accounts — FR-06, FR-07, FR-08, FR-11

Local save completion and network sync are separate states. Present locally saved data immediately. Settings may show account unavailable, offline, observed sync activity/failure, or status unknown, depending on supported signals. Last successful observed sync activity is not proof that every record is present on every device.

Account monitoring uses supported APIs; diagnostic bridging must be encapsulated and verified against minimum OS versions. Provide localized actions for sign-in, connectivity, storage issues, or retrying a local save. Never log full user URLs or titles.

Follow the account policy in the requirements. Prototype account-scoped local store selection and managed-container transition behavior, retaining recovery copies and requiring explicit consent before importing data into a different account. No automatic destructive reset, sign-out purge, or silent cross-account transfer is permitted.

### Favicon cache and privacy — FR-12

Favicon bytes do not enter the initial synced schema. Migrate existing bytes into the local cache if practical; otherwise safely refetch. Cache by URL/domain as appropriate, with expiration and bounded disk usage. Honor the existing favicon preference; explain in the privacy documentation that fetching icons contacts external hosts. UserDefaults stores device preferences only in the new design.

## Legacy migration — FR-10

1. Read `LinkShelf_Links` JSON and `LinkShelf_Folders` from existing App Group defaults. Preserve original bytes in a recoverable backup before modifications; also inspect the historical standard-defaults fallback when the shared source is absent.
2. Decode and validate without converting decode failure into an empty successful import. Report corrupt records and retain the source for recovery; do not discard invalid historic URLs.
3. Build folders from both explicit empty-folder paths and paths referenced by links. Preserve nested structure and legacy relative order. Preserve every link UUID; detect conflicting duplicate IDs explicitly.
4. Import in resumable batches using stable identities and a durable local checkpoint. Prevent app and extension legacy writes during cutover; defer extension saves with a retryable message until migration is complete.
5. Re-fetch and verify IDs, fields, folder mapping, and counts. Mark migration complete only after verification. A crash before that mark must be safely retryable.
6. Switch both processes to SwiftData as the sole write path. Retain the legacy backup according to the release policy; do not dual-write UserDefaults and SwiftData.
7. Let imported records sync through the normal managed path. Reconcile equivalent data already imported on another device; local migration success is separate from cloud upload completion.

Rollback is a documented recovery/export workflow, not an automatic downgrade to two active stores. An older installed app may not understand new changes; test upgrades and describe the limits of returning to an older release.

## Schema evolution, testing, and release

Treat deployed CloudKit schemas as durable contracts: prefer additive changes, retain legacy fields while older clients depend on them, and separate local migration from cloud schema deployment. Initialize development schemas only in controlled development tooling. Promote reviewed changes to production before TestFlight testing. Never repair schema failures by wiping user databases.

Automated package tests cover URL case-sensitive paths, validation, duplicates, deterministic ranks, folder cycles, CRUD/save failures, persistent reopen, corrupted legacy input, interrupted/repeated migration, and old-schema upgrades. Use disk-backed test stores where in-memory behavior is insufficient.

Real-device integration tests cover Mac + iPhone convergence, offline operations, app/extension concurrent writes, same-field and different-field edits, folder rename/move/delete races, duplicate reconciliation, account changes, iCloud unavailable/quota failures where reproducible, relaunch, and mixed package/schema versions. Run both development and production/TestFlight configurations. Record observed sync delays without turning them into a delivery guarantee.

Profile the reference collection defined in NFR-02. Document effective deployment targets, capabilities/provisioning, production schema promotion, package versions, recovery procedures, privacy disclosures, and localization/accessibility validation in the release checklist. Existing macOS lint/build checks still apply when Swift changes begin.

## Implementation checkpoints

- Architecture prototype resolves minimum-OS extension refresh, sync observability, account isolation, and conflict/deletion semantics.
- Package v0.x supplies versioned models, domain rules, repository operations, tests, and a container factory.
- Mac cutover supplies verified migration, favicon cache separation, and shared-store extension integration.
- iOS app supplies native feature parity and a Share Extension using the same package version contract.
- CloudKit release supplies proven convergence, production schema deployment, and recovery/support documentation.

## Apple references

- [SwiftData model container](https://developer.apple.com/documentation/swiftdata/modelcontainer).
- [Configuring App Group storage](https://developer.apple.com/documentation/swiftdata/modelconfiguration/groupcontainer-swift.struct).
- [SwiftData device synchronization and model restrictions](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices).
- [CloudKit model compatibility and schema promotion](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit).
