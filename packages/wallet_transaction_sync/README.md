# Wallet Transaction Sync

`wallet_transaction_sync` is the application-internal boundary for Bitcoin and Liquid transaction synchronization, source-local reconstruction, freshness evidence, and immutable process-local transaction snapshots.

## Ownership

The package owns:

- explicit routine synchronization and explicit history discovery;
- reconstruction from already-persisted BDK/LWK state without network access;
- normalized SDK-independent transaction entities;
- immutable per-wallet/network snapshots;
- exact local lookup and revision-bound pagination;
- content fingerprints, freshness receipts, capabilities, and evidence levels;
- replaying synchronization state;
- registration mismatch and deletion lifecycle;
- shared serialization of access to persisted wallet-source state;
- BDK and LWK source adapters.
- the package-owned durable SQLite metadata adapter, storing hashed keys and non-sensitive synchronization state only; its database path is injected by the production shell.

The package does not own:

- BDK's transaction graph, local chain, keychain index, or persister;
- LWK's wollet state;
- a second durable transaction database;
- labels, swaps, exchange-order enrichment, or presentation mapping;
- spend construction, signing, broadcast, key material, or UI.

BDK and LWK remain the durable authorities. A package snapshot is a reconstructible read model for one process.

## Layering

```text
WalletTransactionSyncFacade
  -> thin domain use case
  -> WalletTransactionRepository
  -> WalletTransactionSourcePort
  -> BDK or LWK data adapter
  -> authoritative persisted SDK state
```

The public library is `lib/wallet_transaction_sync.dart`. Domain entities, requests, failures, states, ports, the coordinator, and the facade are public. Repository implementations, the snapshot store, SDK mappers, and SDK source adapters remain under `lib/src/`.

SDK types are confined to `src/data/bdk/` and `src/data/lwk/`; they never cross the repository or facade boundary.

## Public operations

| Operation | Network | Purpose |
|---|---:|---|
| `synchronizeWallet` | Yes | Synchronize known source state, persist it through BDK/LWK, extract one coherent observation, and publish a snapshot. |
| `discoverWalletHistory` | Yes | Perform explicit restoration/history discovery and publish the reconstructed source state. |
| `refreshLocalSnapshot` | No | Reconstruct a snapshot only from already-persisted BDK/LWK state. |
| `lookupLocal` | No | Look up one transaction in the current in-memory revision. |
| `listLocal` | No | Read one revision through deterministic, revision-bound pagination. |
| `watchWalletState` | No | Replay and observe package state transitions; it never initiates synchronization. |
| `deleteWallet` | No | Evict the snapshot, delete source state through the adapter, clear metadata, and retire the source key. |
| `dispose` | No | Close package state streams. |

Local reads mean “what this wallet knew after its last persisted source observation,” not current blockchain or mempool truth.

## Registration and identity

Every source operation carries a `WalletSourceRegistration` containing:

- `WalletNetworkKey(walletId, chain, network)`;
- a source kind;
- a non-reversible configuration fingerprint;
- the ephemeral source configuration required to open the wallet.

`BdkElectrumConfiguration` identifies a Bitcoin wallet by public external/internal descriptors and network. `LwkElectrumConfiguration` identifies a Liquid wallet by confidential watch-only descriptor and network. Endpoints, tuning, validation policy, and storage paths do not define wallet identity and therefore do not alter the fingerprint.

Reusing a key with another identity returns `WalletRegistrationMismatchFailure`; replacement requires explicit deletion followed by successful discovery.

Descriptor-bearing configurations are operation inputs. Metadata implementations may persist receipts, timestamps, deletion phases, and content fingerprints, but must not serialize descriptors. Configuration and registration `toString()` methods do not reveal descriptor content, endpoints, or storage paths. `BdkElectrumConfiguration.toMap()` is an unredacted configuration view that includes public descriptors and must not be used for persistence, logging, analytics, or diagnostics; it exists for in-process configuration handling, not as a safe serialization contract.

## Snapshot and fingerprint contract

`WalletTransactionSnapshot` contains:

- wallet/network key and source kind;
- immutable normalized transactions and an exact txid index;
- content fingerprint and revision;
- observation time and last durable successful synchronization time when known;
- source capabilities and source tip when exposed;
- completeness and evidence level.

The repository validates the source observation's wallet key, source kind, and configuration identity before publication. A changed modeled value produces one new revision. Semantically identical content keeps the revision and may update freshness metadata. Pagination cursors include their source revision and expire after a content change.

The fingerprint includes transaction identity, amount, fee, vsize, direction, self-transfer, original input/output positions, outpoints, values, assets, scripts, addresses, ownership chain, spend/height state, transaction position, evidence/details, source tip, and completeness. Observation-method metadata such as capabilities is excluded so a local reconstruction can reproduce the content fingerprint of the same network observation.

## State and failures

The replaying state stream uses:

- `WalletStateUninitialized`;
- `WalletStateLoadingLocal`;
- `WalletStateSyncing`;
- `WalletStateReady`;
- `WalletStateReadyWithWarning` when snapshot publication succeeded but freshness metadata was not durable;
- `WalletStateFailed` while preserving the previous readable revision;
- `WalletStateRegistrationMismatch`;
- `WalletStateDeleted`.

Recoverable source, extraction, coordination, pagination, registration, and deletion outcomes are values in the sealed `WalletTransactionSyncFailure` family. SDK exception strings do not become public user messages.

## Shared source coordination

`WalletSourceOperationCoordinator` serializes operations by `(walletId, chain, network)`. `DurableWalletSourceOperationCoordinator` starts one dedicated actor isolate per operation. The actor performs directory creation, schema initialization, central SQLite coordination, and acquisition of one SQLite mutex database per hashed key; it holds that mutex connection and `BEGIN IMMEDIATE` for the complete source lifetime. No wallet identifier or transaction identifier is stored in these databases or lock filenames. The central database is injected by the shell and is not the Drift application schema.

Requests are ordered foreground-first and FIFO within a priority. A foreground request never preempts an active operation. Pending requests heartbeat while waiting and may be removed after the configurable `pendingHeartbeatTimeout`; this TTL applies only to request rows that hold neither mutex nor claim. Admission rechecks that the caller's row still exists before activation. `acquisitionTimeout` bounds only request/mutex admission; the operation `timeout` is separate and cooperative. Active claims have no TTL or heartbeat lease. SQLite releases the per-key mutex on cooperative connection close or process exit, so a stale claim is replaced only after the mutex is acquired. Every operation receives a short-lived `WalletSourceSession`; durable sessions expose their claim capability. While a session is open, the actor-held mutex makes the claim unreplaceable, so `ensureOpen()` performs the local closed-state check without a synchronous database round trip. Retire/reactivate commands are ordered through the actor and awaited by `close()`. A timeout reports to the caller but does not release the key, claim, or session while timed-out work still runs.

Coordination failures use stable sanitized categories: admission timeout, retired source, superseded request, unsupported schema, filesystem setup, busy SQLite coordination, or generic coordination failure. Categories preserve caller decisions without exposing database paths, lock paths, or raw SQLite details.

An isolate must finish its task cooperatively so the coordinator can dispose its SQLite connection. An abnormal isolate-only termination can retain an FFI handle until the containing process exits; the coordinator deliberately remains unavailable instead of using a lease to risk a second LWK writer. Process-exit recovery must be verified separately on each target platform.

The in-memory coordinator remains available for compatibility and tests. `synchronize` and `discover` use a disabled cooperative timeout because real network work can exceed 30 seconds; local refresh and deletion retain the default cooperative timeout. Process-death recovery is provided by SQLite connection cleanup; a true kill/restart test remains an environment-level device/process test, not a TTL-based ownership mechanism.

Successful deletion retires the source key. Work that captured stale metadata before deletion cannot acquire a usable session afterwards. Partial deletion remains resumable, and only explicit successful discovery may reactivate a retired key.

The root application currently injects one coordinator into legacy BDK/LWK repositories and Payjoin adapters. This is the compatibility boundary that prevents legacy and future package-owned operations from racing over the same persisted wallet state.

## BDK adapter

The BDK source adapter:

- uses the explicitly configured SQLite path;
- distinguishes local reconstruction, routine revealed-script sync, and full discovery;
- tries Electrum endpoints before source mutation, then applies and persists one selected update;
- owns a short-lived wallet/persister pair and disposes the wallet before the persister;
- maps canonical transaction position, including block identity when the installed SDK exposes it;
- never silently deletes authoritative BDK state after a generic load error.

## LWK adapter

The LWK source adapter:

- opens an operation-owned public watch-only wallet against the configured root;
- uses the installed LWK synchronization capability with ordered Electrum fallback;
- obtains one coherent complete snapshot through `transactionsProjection(includeUnblindingData: false)`;
- preserves nullable vin/vout positions as original indexes plus total slot counts without coercing unknown third-party entries to zero;
- retains outpoints, asset IDs, canonical scripts, standard/confidential address strings, spend state, heights, and external/internal ownership chain for present wallet-owned records;
- computes transaction amount from the network's L-BTC policy asset only and excludes internal L-BTC change from self-transfer amount;
- maps source height/time only to source-reported confirmation evidence and never invents a block hash, tip, confirmation count, or mempool proof;
- maps incompatible persisted status to `WalletSourceStateIncompatibleFailure` instead of deleting source state;
- deletes only the explicitly configured database root.

The installed LWK SDK revision exposes no wallet `close` or `dispose` API for this public watch-only object. The complete projection is therefore extracted before coordinator release; the opaque SDK object becomes unreachable and is reclaimed by the runtime.

Unblinding factors never enter compact records. Package history always requests `includeUnblindingData: false`; the legacy exact-detail viewer remains a separate, explicitly reviewed in-memory path.

## Migration status

The package facade and both source adapters are implemented and independently testable. The shared coordinator already protects legacy application consumers. The application composition root does not yet make `WalletTransactionSyncFacade` the production transaction-history owner, and legacy repositories still feed the UI.

Before cutover:

1. Publish the immutable upstream LWK and `bull_sdk` commits and resolve them without local Git rewriting.
2. Run disabled shadow comparisons after the active legacy read without exposing transaction content in diagnostics.
3. Verify restart, interrupted deletion, descriptor replacement, source failures, and multi-wallet lifecycle behavior proportionately.
4. Authorize details, wallet-list, and aggregate-list cutovers separately behind rollback flags.

The dated benchmarks, Red-Green reproductions, commit chain, Android measurements, and delivery gates live in the external implementation plan rather than this durable package contract.

## Verification

Use the repository makefile and pinned Flutter SDK. The package tests mirror behavior across source mapping, fingerprint stability, pagination, watchers, deletion, lifecycle, concurrency, and immutability. The optional network discovery test remains explicit and is not part of the default deterministic suite.
