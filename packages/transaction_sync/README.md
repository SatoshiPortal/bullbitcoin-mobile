# Wallet Transaction Sync

`transaction_sync` is the application-internal boundary for Bitcoin and Liquid transaction synchronization, source-local reconstruction, freshness evidence, and immutable process-local transaction snapshots.

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
- BDK Electrum/compact-filter and LWK Electrum source adapters.
- retained multi-wallet CBF nodes and peer-to-peer broadcast, persisting pending transactions before route verification or network access.
- the package-owned durable SQLite metadata adapter, storing hashed keys and non-sensitive synchronization state only; its database path is injected by the production shell.
- the BDK Electrum download cache: a `<wallet database>.parents.sqlite` sidecar holding the public parent transactions of the wallet's transactions, never read as transaction history.

The package does not own:

- BDK's transaction graph, local chain, keychain index, or persister;
- LWK's wollet state;
- a second durable transaction database;
- labels, swaps, exchange-order enrichment, or presentation mapping;
- spend construction, signing, Electrum broadcast, key material, or UI.

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

The public library is `lib/transaction_sync.dart`. Domain entities, requests, failures, states, ports, the coordinator, and the facade are public. Repository implementations, the snapshot store, SDK mappers, and SDK source adapters remain under `lib/src/`.

SDK types are confined to `src/data/bdk/` and `src/data/lwk/`; they never cross the repository or facade boundary. The separate `lib/bdk_electrum_cache.dart` library exposes `BdkElectrumCache` to the application's legacy BDK sync until that sync runs behind the facade; it takes SDK types by design and is not part of the facade contract.

## Bitcoin import policy inputs

`BitcoinSyncSource` lives in `primitives` and is re-exported here for compatibility. The preference is stored in application wallet metadata. Electrum remains the default and Liquid always uses it; CBF is confirmed-only.

The shell rereads saved policy for dispatch; the reactive adapter revalidates it inside each short storage session. CBF network waits hold no wallet source session. `BdkCbfConfiguration` supplies the initial policy checkpoint and required-Tor flag. Missing required SOCKS routing produces a typed refusal, never a direct connection or Electrum fallback.

The shell's legacy coordinator guard covers history synchronization/discovery only. Other remote operations need a wallet-attributed privacy guard.

`BitcoinSyncCheckpoint` supplies height, hash and block timestamp. The offline resolver clamps stored future birthdays to its reference clock, rounds to the UTC day, subtracts seven days and chooses a verified monthly predecessor. It never queries a server or substitutes import time for unknown history.

The mainnet catalogue covers February 2012 through October 2026. `ResolveBitcoinSyncCheckpointUsecase.execute` takes `scriptType: BitcoinSyncScriptType`; derive it from the output descriptor with `BitcoinSyncScriptType.fromDescriptor`, rather than its key-origin BIP purpose. Unknown birthdays and dates before a script's supported start use its exact floor: Taproot block 709631 (before activation block 709632), SegWit v0 including nested SegWit block 481823, and pre-SegWit HD wallets block 164780 (last header timestamp strictly before BIP32 publication, February 1, 2012 UTC). The optional parameter defaults to SegWit v0 for compatibility; callers with a descriptor must supply its actual kind. Test networks retain their own genesis. Known dates keep the seven-day margin and choose a monthly checkpoint, clamped upwards to the script floor. Header timestamps do not prove wall-clock activity time.

The 67 additional monthly records were verified on October 28–29, 2026 using only public block data from [Bull's explorer](https://mempool.bullbitcoin.com/api) and [mempool.space](https://mempool.space/api), following the [REST API reference](https://mempool.space/docs/api/rest). At both sources, fetch `/block-height/<height>` then `/block/<hash>` for the predecessor and successor; require identical hash, height, header time, median time and parent hash, linked blocks, and `predecessor.timestamp < monthStart <= successor.timestamp`. Timestamp lookup is only a search hint: the February 2012 hint returned block 164750, which failed bracketing and was rejected. Matching `/blocks/<height>` batches locate an upper bound with median time on/after the cutoff; scan all intervening heights backwards to the last timestamp strictly before the cutoff, without assuming monotonic header timestamps. The monotonically advancing median time bounds later blocks. Recheck the exact selected pair with height/hash and block endpoints. Verify consecutive month cutoffs, increasing selected heights/times, and a newest cutoff at least fourteen days old.

BIP32's pair is 164780 (`000000000000087bb253be417ce7df3235a812350d1e05a4c224c4fc448cceef`, timestamp 1328053905) → 164781 (1328054418), bracketing 1328054400. Taproot's pair is 709631 (`000000000000000000013712fc242ee6dd28476d0e9c931c75f83e6974c6bccc`, timestamp 1636865834) → 709632 (1636866927). Both explorers matched; SegWit's existing floor was rechecked. Adding the small offline monthly extension avoids years of unnecessary scanning for a known 2015 birthday, with no runtime explorer request.

## Compact block filters

`BdkCbfConfiguration` shares the existing BDK identity fingerprint and registration kind (`bdk_electrum`) so changing transport preserves authoritative wallet state. Its configuration type and snapshot capabilities identify CBF; the historical registration kind does not select transport. SDK objects remain inside `src/data/bdk/`. The temporary root binding override is for the stacked integration; the final upstream change must update `bull_sdk` to consume the corrected binding revision.

The foreground retains one native node per Bitcoin network while visible and at least one CBF wallet exists. Transient `inactive` focus loss preserves the node. Desktop `hidden` and `paused` states also preserve it; mobile visibility loss drains and stops it, and `detached` always stops it. `CbfBuilder.buildWithWallets` uses `SyncScanType` from the wallets' persisted checkpoints. A 100 ms Dart timer renews the 5-second native owner lease and drains `pollUpdateBatch()` in FIFO order. Each per-wallet update is applied, persisted and disposed before the next batch. Globally aligned 1,000-height boundaries carry a safe frontier and `syncedToTip`; only the final flag authorizes discovery completion and a successful full-sync receipt. Partial observations remain incomplete and preserve the last full-sync timestamp. Overflow at eight batches stops native work; the app drains retained batches before joining and rebuilding. Synchronous diagnostics report progress but never complete recovery. No streaming receive or native termination future is retained by the owner, and the node never retains a wallet writer. Graceful pause and same-policy rebuild share one drain operation; deletion and policy invalidation keep a separate immediate stop so a caller holding a source lock cannot deadlock on itself. Storage failures stop the node and remain visible.

A survivor isolate owns each native termination witness and asynchronous package submission; submission callbacks therefore remain alive when their application owner dies. Both foreground and headless registries arm a 7-second owner-exit bound (5-second TTL plus 2 seconds for cancellation scheduling) and register every witness before native run. After that interval, replacement still requires all witnesses to acknowledge actual native termination. An OS DNS resolver on Tokio’s blocking pool can outlive cancellation, so an absent acknowledgement keeps the owner quarantined until the resolver returns. The bound never substitutes for a failed native join.

Recovering wallets load with lookahead 1000. Their first scan index atomically saves the initial birthday checkpoint and revealed derivation bounds; later starts reuse that policy-scoped persisted index, including its chain and script-window state. The birthday resolver identifies policy and the initial anchor, never a replacement for existing scan progress. This public index can start below an already-ahead source wallet for an explicitly earlier birthday; application history still reads only the authoritative source wallet. Every boundary commits to that source first, then the index, so a crash may replay a boundary but cannot skip unapplied wallet data. Source loss invalidates an orphaned index, and deletion removes all policy indexes. A per-wallet completion marker matches identity, initial checkpoint, script count and policy version, and is written only after the final boundary is persisted and published. An incomplete recovery with a saved boundary may resume in a bounded background catch-up; a first recovery or empty replacement store cannot start there.

Wallet-set, source and Tor on/off/port changes stop and join the old node before replacement. An earlier birthday starts a replacement recovery immediately. Each node owns its configured public scan indexes and prepared batches; rebuilding at the exact checkpoint prevents an older queued boundary from falsely completing the new policy. Ordinary blocks and user refreshes keep the node and its peers.

The script window is **1000 per keychain** beyond the captured revealed bound. It is finite, not arbitrary gap discovery. Before exposing a receive script outside that window, and before relaying a transaction that may reveal change, the shell checks the current SDK derivation bounds and rebuilds only when coverage is exceeded. Both keychains are checked. History outside the supported window still needs a wider recovery policy. Confirmed chain data and locally saved pending transactions remain distinct; pending does not prove mempool acceptance.

`watchBitcoinSyncProgress(key)` replays SDK-free phases `findingPeers`, `checkingBlocks`, `downloadingTransactions`, and `done`. Fractions count filters, not headers. `SyncedInfo` is a prepared native boundary, not durable success; `done` follows application persistence while the node stays connected. Old queued heights do not regress a durable boundary. New generations reset peer and target observations while retaining each wallet's durable scanned height; displayed fractions use the original policy anchor rather than the restarted native scan fraction. Reactive failures also update `watchWalletState`, retaining the last successful snapshot.

Foreground recovery has no whole-history timeout. Initial peer admission is bounded to ten minutes without contact; after contact, three minutes without advancing chain/filter headers, checked filters, blocks or a durable batch rebuilds the node. An idle wallet already at tip is exempt. Repeated handshakes cannot mask a stall. Transport failures and peer loss reconnect without ending the recovery: retries start immediately, then use exponential delays capped at 30 seconds with 50–100% jitter, reset by real progress or foreground/network re-admission. Pause and offline admission cancel a pending retry. Every current native Info variant records peer contact; retained progress, the durable dropped-Info counter and the durable synced tip preserve that evidence even if the handshake diagnostic is evicted. Admission records observed contact, not a current peer count or a successful broadcast: only the native transaction-payload relay acknowledgement completes broadcast. Request deadlines are never retained as node lifetime policy. `catchUpCbfWallets` runs one bounded multi-wallet background batch, excludes first recoveries without a saved boundary and missing stores individually, persists intermediate outcomes until tip or its absolute budget, then drains and stops the node before returning. The shell reserves join time per network and time for Liquid. Cached results can settle queue claims without starting new network work after network admission ends. Foreground/headless handoff uses a stop/termination acknowledgement and an active-foreground marker, preventing a worker started after resume from creating another node.

Shutdown requests stop the native node, then join it. Three bounded join waits can return `CbfNodeDidNotStopFailure`; the network barrier and native handles remain until actual termination, including during foreground/headless handoff. Native OS DNS teardown can therefore outlive a platform budget; no unconditional OS deadline or isolate-kill guarantee is claimed. Admitted storage/publication callbacks keep their source session and are drained before dependencies close. Other wallet reads and spending remain available while native networking waits.

`stageCbfTransaction` saves pending before the shell verifies Tor. `broadcastCbfTransaction` reuses the network's running node, starting it with the complete wallet registry if needed, waits for an established peer, and submits a singleton package. Its total 30-second budget includes route preparation and handshake. Acknowledgement means transmission to a peer, not mempool acceptance; timeout or Tor refusal preserves pending and never falls back to Electrum. CBF network requests enter without an already-admitted source session; legacy admitted Electrum operations retain their existing contract.

Peer persistence is deliberately absent. The bindings expose `peerCount`, `peerInfo`, `connect`, builder `peers` and `onlyConfiguredPeers` for diagnostics or explicitly selected seeds. They do not expose import/export of the complete discovered address book. Reusing peers across restarts needs a privacy decision and additional native support.

## Public operations

| Operation | Network | Purpose |
|---|---:|---|
| `synchronizeWallet` | Yes | Synchronize known source state, persist it through BDK/LWK, extract one coherent observation, and publish a snapshot. |
| `discoverWalletHistory` | Yes | Perform explicit restoration/history discovery and publish the reconstructed source state. |
| `refreshLocalSnapshot` | No | Reconstruct a snapshot only from already-persisted BDK/LWK state. |
| `lookupLocal` | No | Look up one transaction in the current in-memory revision. |
| `listLocal` | No | Read one revision through deterministic, revision-bound pagination. |
| `watchBitcoinSyncProgress` | No | Observe replaying per-wallet CBF filter progress without initiating network work. |
| `reconcileCbfWallets` | Yes | Maintain the complete foreground CBF wallet registry and node generations. |
| `ensureCbfScriptCoverage` | If needed | Rebuild when a revealed receive/change script exceeds the captured window. |
| `catchUpCbfWallets` | Yes | Run a bounded multi-wallet background catch-up and return outcomes per wallet. |
| `stageCbfTransaction` | No | Save pending before route verification. |
| `broadcastCbfTransaction` | Yes | Persist pending and relay through the retained P2P node with required Tor. |
| `stopCbfNodes` | No new work | Stop/join all network nodes, retaining an unacknowledged network barrier. |
| `watchWalletState` | No | Replay and observe package state transitions; it never initiates synchronization. |
| `deleteWallet` | No | Evict the snapshot, delete source state through the adapter, clear metadata, and retire the source key. |
| `dispose` | No new work | Stop nodes, drain admitted publication callbacks, and close state streams. |

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

`WalletSourceOperationCoordinator` serializes operations by `(walletId, chain, network)`. `DurableWalletSourceOperationCoordinator` starts one dedicated actor isolate per operation. The actor performs directory creation, schema initialization, central SQLite coordination, and acquisition of one SQLite mutex database per hashed key; it holds that mutex connection and `BEGIN IMMEDIATE` for the complete source lifetime. Network synchronization and discovery additionally hold one of the configured global SQLite slot files (two by default) for the complete source lifetime; callers configure this with `maxActiveSynchronizations`. All coordinators sharing a central database must use the same capacity; initialization rejects a mismatch. SQLite releases both physical locks on cooperative session close or process death. An abnormal actor-isolate exit fails closed because native SQLite handles are not assumed to be reclaimed before process restart. The actor watches its caller isolate: a caller that exits while waiting leaves the queue at once; one that exits during its operation, as when Android destroys a WorkManager engine, keeps the source for `orphanedOperationGrace` (60 s by default), because native work it started may still write the wallet, and the actor then releases and closes the locks itself. Central claims remain diagnostic metadata only. No wallet identifier or transaction identifier is stored in these databases or lock filenames. The central database is injected by the shell and is not the Drift application schema.

The shell may inject a `WalletCoordinationLogSink`. Lifecycle events contain an ephemeral operation token, normalized chain/network, operation kind and priority, queue/elapsed timing, and fixed failure categories. They never contain wallet identifiers, source-key hashes, fingerprints, descriptors, addresses, transaction identifiers, amounts, server endpoints, or raw exceptions.

Requests are ordered foreground-first and FIFO within a priority, including global synchronization admission among keys without an active claim. A foreground request never preempts an active operation. Pending requests heartbeat while waiting and may be removed after the configurable `pendingHeartbeatTimeout`; this TTL applies only to request rows that hold neither mutex nor claim. Admission rechecks that the caller's row still exists before activation. `acquisitionTimeout` bounds request, key-mutex, and global-slot admission, except for foreground refreshes, which wait for the operation in front of them since the user sees its progress; the operation `timeout` is separate and cooperative. Active claims have no TTL or heartbeat lease. SQLite releases the per-key mutex and physical synchronization slot on cooperative connection close or process exit, so stale claims are replaced only after the key mutex is acquired; a waiting global request clears a claim whose key mutex it can take, so a claim left by a killed process does not keep its key out of admission. Every operation receives a short-lived `WalletSourceSession`; durable sessions expose their claim capability. While a session is open, the actor-held mutex makes the claim unreplaceable, so `ensureOpen()` performs the local closed-state check without a synchronous database round trip. Retire/reactivate commands are ordered through the actor and awaited by `close()`. A timeout reports to the caller but does not release the key, claim, or session while timed-out work still runs.

Coordination failures use stable sanitized categories: admission timeout, retired source, superseded request, unsupported schema, filesystem setup, busy SQLite coordination, or generic coordination failure. Categories preserve caller decisions without exposing database paths, lock paths, or raw SQLite details.

An isolate must finish its task cooperatively so the coordinator can dispose its SQLite connection. The caller owns the actor's key and slot connections and its queue request from their creation: a short-lived isolate that is never killed opens the connections and the caller chooses the request token, so nothing depends on the actor surviving. The actor only rolls the connections back, which frees the locks, and exits on its own after a normal release; the caller closes them, and removes a request the actor did not clean, once the actor has exited and the coordinator has seen the operation callback settle. A session's public `close()` only ends its use: the source stays exclusive until the callback settles, even when the actor died. If the whole Flutter engine holding the caller is destroyed, those connections stay open until the process exits; the coordinator deliberately remains unavailable then instead of using a lease to risk a second LWK writer. Process-exit recovery must be verified separately on each target platform.

The in-memory coordinator remains available for compatibility and tests. `synchronize` and `discover` use a disabled cooperative timeout because real network work can exceed 30 seconds; local refresh and deletion retain the default cooperative timeout. Process-death recovery is provided by SQLite connection cleanup; a true kill/restart test remains an environment-level device/process test, not a TTL-based ownership mechanism.

Successful deletion retires the source key. Work that captured stale metadata before deletion cannot acquire a usable session afterwards. Partial deletion remains resumable, and only explicit successful discovery may reactivate a retired key.

The root application currently injects one coordinator into legacy BDK/LWK repositories and Payjoin adapters. This is the compatibility boundary that prevents legacy and future package-owned operations from racing over the same persisted wallet state.

## BDK adapter

The BDK source adapter:

- uses the explicitly configured SQLite path;
- distinguishes local reconstruction, routine revealed-script sync, and full discovery;
- tries Electrum endpoints before source mutation, then applies and persists one selected update;
- prefills each fresh Electrum client with the wallet's transactions, their direct confirmation anchors and the cached parent transactions, then stores the parents the scan fetched; the server still answers every script history and header request, an anchor that no longer matches its block header is verified again with a Merkle proof, and a cache failure only costs the downloads;
- deletes the cache sidecar with the wallet;
- owns a short-lived wallet/persister pair and disposes the wallet before the persister;
- maps canonical transaction position, including block identity when the installed SDK exposes it;
- never silently deletes authoritative BDK state after a generic load error.

## LWK adapter

The LWK source adapter:

- opens an operation-owned public watch-only wallet against the configured root;
- uses the installed LWK synchronization capability with ordered Electrum fallback;
- obtains a coherent wallet-transaction list through the installed `Wallet.txs()` API;
- preserves output indexes from their outpoints; input positions and total input/output counts remain unknown because this SDK filters missing entries;
- retains public outpoints, asset IDs, scripts, address strings, spend state and heights; identifies external chains only through derived receiving-address matches and leaves other chains unknown;
- computes amounts from the network's L-BTC policy asset; self-transfers count only receiving-address matches, following the existing application semantics;
- maps source height/time only to source-reported confirmation evidence and never invents a block hash, tip, confirmation count, or mempool proof;
- maps incompatible persisted status to `WalletSourceStateIncompatibleFailure` instead of deleting source state;
- deletes only the explicitly configured database root.

The operation-owned wallet is disposed after extraction and before coordinator release. Address matching uses the receiving addresses through the last-unused index; the SDK does not expose an internal-chain marker for transaction records.

The installed SDK materializes unblinding factors and URLs in memory when returning transactions. The mapper reads only public values and never copies factors, blinding keys or URLs into synchronization records. The legacy exact-detail viewer can receive its in-memory URL; history list models omit it. This compatibility path retains full-list extraction rather than claiming an unavailable targeted SDK lookup.

## Migration status

The package facade and both source adapters are implemented and independently testable. The shared coordinator already protects legacy application consumers. The application composition root does not yet make `WalletTransactionSyncFacade` the production transaction-history owner, and legacy repositories still feed the UI.

Before cutover:

1. Keep the application and adapter on the same pinned SDK revision.
2. Run disabled shadow comparisons after the active legacy read without exposing transaction content in diagnostics.
3. Verify restart, interrupted deletion, descriptor replacement, source failures, and multi-wallet lifecycle behavior proportionately.
4. Authorize details, wallet-list, and aggregate-list cutovers separately behind rollback flags.

The dated benchmarks, Red-Green reproductions, commit chain, Android measurements, and delivery gates live in the external implementation plan rather than this durable package contract.

## Verification

Use the repository makefile and pinned Flutter SDK. The package tests mirror behavior across source mapping, fingerprint stability, pagination, watchers, deletion, lifecycle, concurrency, and immutability. The optional network discovery tests remain explicit and are not part of the default deterministic suite. `CBF_LIVE_TESTS=1 fvm flutter test test/cbf_live_recovery_test.dart` (from this package) recovers the public account-0 BIP84 descriptors from a recent exact checkpoint, compares confirmed transaction sets with Electrum, and performs a warm catch-up. Only this opt-in comparison intentionally uses both transports; production CBF operations never do.
