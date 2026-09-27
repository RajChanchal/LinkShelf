# LinkShelf multi-device requirements

Status: proposed product baseline. The shared package from delivery step 2 has been started in [`LinkShelfKit/`](../LinkShelfKit/README.md) and is not yet linked into either app. The step 1 device prototype has not started.
Date: 2026-09-27.
Companion: [Feature and architecture specification](FEATURE_SPECIFICATION.md).

## Product objective

Let a person save, organize, find, copy, and open their links on Mac and iPhone, with offline access and automatic synchronization through their own iCloud account. Preserve existing Mac collections during the move from UserDefaults to SwiftData.

## Decisions and scope

- Use SwiftData for local persistence and its managed CloudKit integration for device synchronization.
- Deliver a native iOS app alongside the existing macOS menu bar app.
- Share the data layer through a versioned Swift Package Manager package, usable from separate application repositories.
- Minimum versions: macOS 14 (confirmed 2026-09-27) and iOS 17 (proposed). SwiftData adoption ends support for macOS 11–13 in new releases.
- Use a shared CloudKit container and its private database for each person's collection. App Groups provide local access between an app and its extensions; they do not provide cross-device synchronization.
- Keep preferences in UserDefaults and favicon images in a replaceable local cache.

The project, README, and project guidelines now consistently specify macOS 14 as the minimum.

First release includes iPhone, macOS, and their Share Extensions. Android, web clients, public collections, collaboration between different users, custom sync servers, widgets, and full iPad-specific layouts are outside this baseline. iPad distribution eligibility must be selected explicitly before submission.

## Functional requirements and acceptance

| ID | Requirement | Acceptance condition |
| --- | --- | --- |
| FR-01 | Save, edit, copy, open, and delete links on both platforms. | A valid title and HTTP(S) URL can be saved offline, survive restart, and support all listed actions. Failed saves preserve entered values and show a localized error. |
| FR-02 | Preserve meaningful URL content. | Missing schemes become HTTPS; host/scheme comparison is case-insensitive, but path/query case, fragments, query ordering, and trailing slashes are not silently discarded. Invalid or unsupported URLs cannot be newly saved or opened. |
| FR-03 | Organize links in persistent, nested folders. | Empty folders persist; moving and renaming preserve identity; cycles are rejected. Folder deletion confirms deletion of its links and descendants, matching existing Mac behavior. |
| FR-04 | Search and order the collection. | Search includes title, URL/domain, and folder. Reordering works offline and produces stable ordering after restart and eventual sync, including concurrent moves. |
| FR-05 | Save from the platform share sheet. | Mac and iOS extensions save to their host app's local App Group store, confirm only after durable save, and do not require a network round trip. |
| FR-06 | Synchronize a person's collection across devices. | Links, folders, edits, moves, and deletions converge between a Mac and iPhone signed into the same iCloud account when synchronization is available. No custom LinkShelf account is required. |
| FR-07 | Work without available iCloud or connectivity. | Browsing and mutations remain available locally. Sync unavailability is shown separately from local save failure. Pending work resumes through managed sync when conditions permit. |
| FR-08 | Surface truthful synchronization information. | Settings show observable account availability and actionable failures. UI never promises immediate delivery or labels an individual record fully uploaded without evidence. |
| FR-09 | Reconcile duplicate additions. | Local duplicates are detected before save; identical URLs added on disconnected devices are reconciled deterministically after import without silently discarding divergent edits. |
| FR-10 | Migrate existing Mac data safely. | Existing link UUIDs, titles, URLs, folder hierarchy, empty folders, and relative ordering survive import. Re-running interrupted migration does not multiply records. Original data remains recoverable. |
| FR-11 | Handle account changes safely. | Signing out or switching accounts never uploads one account's collection to another automatically. Offline edits and recovery follow the documented account policy. |
| FR-12 | Keep icons optional. | Missing, stale, or failed favicons never block saving, browsing, migration, or synchronization. Images are refetched locally when permitted. |
| FR-13 | Preserve native platform behavior. | Mac retains menu bar access and its shortcut; iOS supplies touch navigation, copy feedback, system sharing, and accessible forms. |

## Quality requirements

| ID | Requirement | Verification |
| --- | --- | --- |
| NFR-01 | Keep network, import, and large fetch work off the UI actor; isolate persistence contexts appropriately. | Profile browse/search/import on representative supported devices; no synchronous network calls on the main actor. |
| NFR-02 | Handle a reference collection of 10,000 links and 1,000 folders. | Measure cold launch, initial list, search, and mutations in release builds. Initial targets: usable list within 2 seconds and search within 300 ms after debounce on an agreed reference device; record conditions and revise only with evidence. These are local performance targets, not sync SLAs. |
| NFR-03 | Limit unnecessary persistence and network work. | Mutations update records rather than replacing the entire collection. List queries use bounded fetches; do not eagerly decode all favicon images. |
| NFR-04 | Maintain localization and accessibility. | All new UI text uses each app's String Catalog; VoiceOver, Dynamic Type on iOS, keyboard navigation on Mac, and existing supported translations are checked. |
| NFR-05 | Protect privacy and recovery. | URLs, titles, and query parameters are absent from production logs. No destructive store reset occurs automatically. Recovery can export available local records before any explicit reset. |
| NFR-06 | Support independent app release schedules. | Both clients use compatible package/schema versions; older clients remain functional during additive model rollouts. |

## Sync and data policies

Managed sync is asynchronous and eventually consistent. A local save is the immediate success boundary. A local empty store is not proof that the person's cloud collection is empty; first launch must not seed example links or replace cloud data.

Use stable UUIDs for links and folders. Timestamps support diagnostics and duplicate reconciliation, but device clocks must not be treated as an authoritative global ordering mechanism. Managed CloudKit conflict resolution must be characterized in tests; a whole-record "last writer wins" guarantee must not be invented.

Proposed account policy: retain recoverable local data on sign-out, pause app-originated mutations during account transitions, and require an explicit keep-separate/import choice before transferring retained records to a different account. A prototype must establish what SwiftData exposes and how account-scoped stores interact with managed sync before this policy is committed to production.

Sync is automatic when configured and available. A user-facing sync toggle is deferred until safe disable/re-enable and data-retention behavior are defined. Do not offer a "sync now" button that cannot deliver a meaningful supported action.

## Delivery sequence and release gates

1. Prototype SwiftData + CloudKit on minimum supported OS versions. Prove App Group access, extension writes, cross-process UI refresh, account transitions, duplicate reconciliation, and conflict behavior on real devices. Resolve blockers before production model design is frozen.
2. Build the shared package, versioned schema, repository operations, URL rules, and migration tests. Integrate local persistence on Mac and verify extension behavior before enabling production sync.
3. Enable development CloudKit sync and implement the iOS app against the same released package contract. Run the two-device/offline acceptance matrix.
4. Validate additive schema rollout and upgrade compatibility. Promote the tested CloudKit schema to production before TestFlight validation and App Store release.
5. Release with updated platform support, privacy policy, support documentation, recovery guidance, and measured performance results.

Release gates include interrupted migration, concurrent app/extension writes, duplicate offline additions, independent field edits, delete-versus-edit, concurrent reorder, folder delete-versus-move, sign-out/account switch, unavailable iCloud, and development-versus-production behavior. Tests must cover every FR above; CloudKit tests require real signed-in devices in addition to local automated tests.

## Pending product and engineering decisions

- Confirm the iOS minimum, iPhone/iPad distribution scope, and support policy for existing Mac users on macOS 11–13.
- Register or select the CloudKit container and iOS App Group identifiers under the shipping developer team; identifier examples in the companion document are not provisioned resources.
- Confirm the account transition UX and export/recovery format after the sync prototype.
- Confirm performance reference devices and the legacy backup retention period. Suggested baseline: keep the migration backup until the user explicitly removes it after a successful upgrade.

## Apple references

- [SwiftData synchronization and CloudKit model restrictions](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices).
- [SwiftData App Group storage configuration](https://developer.apple.com/documentation/swiftdata/modelconfiguration/groupcontainer-swift.struct).
- [CloudKit-compatible models and production schema promotion](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit).
