# Ark

Protocol boundary for the Scuttle Ark wallet. `ark.dart` publishes accounts, immutable observations, reviewed quotes, journalled operations, receive requests and the `ArkClient` interface. `ark_setup.dart` is the privileged composition surface: it accepts a scoped dedicated-child provider, a host public-transaction-codec verifier, execution policy and stage budget. It must not be re-exported by an ordinary feature facade.

The native wallet is Scuttle's `bark-wallet`, reached through the `rust_lib_scuttle` bridge in `rust/`. Native calls live only in `scuttle_native_opener.dart`. The adapter opens one wallet per account under the account lock and runs no daemon. It never receives the parent seed, signs a BULL source transaction or broadcasts a source-wallet funding PSBT. Synchronization stages never run Scuttle's general sync, which can rebroadcast stored transactions; exit observation uses `progress_exits_without_broadcast`, and every exit CPFP and claim is journalled before delivery.

## Admission and recovery

The host must register a durable parent obligation under parent-custody admission before calling `create`. Lock order is parent admission, package lifecycle admission, account writer, short metadata transaction. The child provider executes inside the account writer and must not reacquire parent admission. A durable obligation protects subsequent scoped derivation. Source-wallet funding admission happens separately after all Ark native locks are released.

Projection reads never open the native wallet. Native stages await their admitted future before closing handles and releasing SQLite rollback-journal locks. A budget revokes only the next stage. `backgroundExisting` refuses creation, missing or incompatible metadata and native datadirs; it can synchronize and delegate renewal but cannot submit foreground exits/claims or receive/payment requests. The host supplies background eligibility independently of whether Ark is offered as a new payment route.

A quote binds account observation, configuration generation, exact chain provider, fee, selection, destination and review validity. Exit progression also binds the complete live exit set, fixed integer fee rate and confirmed internal reserve coin set/exposure. It authorizes one account-wide attempt. Raw addresses are only syntactically classified by `isArkAddress`; authoritative parsing and estimation stay inside the writer.

Irreversible calls follow durable admission. An exception after admission leaves an unknown operation, never an automatic spend retry. `read` exposes journalled operations after restart; `synchronize` reconciles positive native evidence. Provider absence never proves rejection. Claims use explicit ids, inspect actual/skipped ids, extract the signed transaction, verify PSBT input values/final witnesses plus transaction facts through the host port, debit the cumulative exit authorization and persist the exact signed bytes/txid before broadcast. Skipped ids retain only the remaining fee allowance.

Boarding is `quote(board)` -> `boardFunding(quoteId, operationId)` -> host atomic funding reservation -> `registerBoard` with the exact journalled tuple and unfinalised native-segwit PSBT -> host signing and guarded broadcast. `confirmQuote` cannot board. Registered boards follow an exact unsigned txid; do not change that txid through a generic fee bump. Pending/unknown funding remains an obligation until positive settlement or a separately reviewed proof of conflict/never-signed state. No abandon or cancellation guarantee is exposed. The approved host board flow uses only the fast fee estimate, with no fee chooser or late-funding urgent alert. Source-wallet release remains the host authority's responsibility; no conflicting self-spend is exposed.

## Observations and privacy

Unknown balances/heights/counts are nullable. A stale or incomplete observation is never an unfunded account. Per-exit details, pending boards, operations and VTXO-section completeness support recovery and expiry reminders. Missing formerly live VTXOs or a regressed tip cannot clear an existing warning. A delegated round remains pending until positive replacement evidence; it is not a renewed balance.

Primary and optional fallback Esplora endpoints are configured explicitly. Only a transport failure before any HTTP response/native admission permits fallback. HTTP rejection, malformed data, a different genesis or a regressed tip does not. A reviewed or uncertain operation stays bound to its selected endpoint. Direct Ark/Esplora traffic exposes IP addresses and wallet activity to those providers; this adapter has no Tor transport.

## Verification

Use the repository's pinned FVM toolchain and make targets for integrated checks. The package tests cover public contracts, real SQLite persistence/exclusion across processes, abrupt process death, lifecycle admission through a native fake, quote/idempotency/claim policies and local HTTP fallback discrimination. Native-fake tests do not establish actual Scuttle signing, persistence or network behavior. Native runtime and end-to-end board/payment/renewal/exit proof remain separate integration gates, as do Android background and iOS lifecycle validation.

### Scuttle bridge

The Native Assets hook builds `rust_lib_scuttle` from a separate locked Cargo graph, keeping Scuttle's SQLite dependency out of `rust_lib_bull_sdk`. The exact Scuttle revision and Rust toolchain are recorded in `rust/Cargo.toml` and `rust/rust-toolchain.toml`. Use `make scuttle-codegen` with flutter_rust_bridge_codegen 2.13.0 and libclang after changing the Rust API.

Scuttle's `bark-server-rpc` runs protoc at build time. The Ark feature only opens regtest accounts.

`fvm dart test test/scuttle_bridge_test.dart` from `packages/ark` exercises native loading and the wallet lifecycle against a local genesis response. It does not establish interoperability with a live Scuttle server or constitute mobile packaging validation.

## Already signed claim delivery

`rebroadcastClaim(operationId, expectedTxid)` may run automatically in foreground or `backgroundExisting` for an existing verified signed claim. It uses the account writer and captured Esplora directly, without child derivation, Secrets access, a native wallet, new signing, quote freshness or another authority debit. Other background submissions remain refused. The host runs this lane independently of keyed renewal and supplies protected existing-account admission even when new Ark routing is off.

Each invocation persists its attempt separately from immutable signed evidence and performs at most one POST of exactly the saved raw transaction. Policy and budget are rechecked after verification/preflight and immediately before transport. The POST has its own total15-second bound and128-byte reply limit, disables redirects and awaits owned HTTP abort/cleanup. Preflight retains its existing per-request/inactivity bounds; the entire task is not claimed to have a15-second deadline. A matching reply means pending, not confirmed. Failure or an uncertain reply returns uncertainty and retains signed evidence/debit for a later scheduled invocation. A result-persistence failure may leave the stored operation pending or unknown; neither releases protection or changes the signed transaction. Positive journalled confirmation/conflict suppresses delivery; absence of optional chain evidence does not create new signing or release authority.

## Read stored Bark exit material on demand

`ark_sql.dart` publishes a separate read-only projection. `createArkSqlExitRepository` binds the existing database path, account and independently trusted native fingerprint/server public key. It opens no wallet or file until one of its three methods is called:

- `readVtxo(vtxoId: ...)` returns the exact separate nullable `rawBare` and `rawGenesis` BLOBs. SQL NULL stays null; an empty stored BLOB stays empty. No concatenation, Full encoding, witness or completeness flag is manufactured.
- `readExitState(vtxoId: ...)` returns a typed phase and the processing references recorded by that phase. A VTXO ID is an outpoint; each reference's `parentTxid` is a different identifier. Non-processing phases need not record those references.
- `readExitChild(parentTxid: ...)` returns the complete stored child transaction bytes and typed origin. These source-supplied bytes are not checked for consensus or signature validity.

Each result is `Err(ArkWalletFailure)`, `Ok(ArkSqlNotFound())` or `Ok(ArkSqlFound(value))`. NotFound means only that the requested row was absent in a successfully guarded snapshot. It says nothing about funds, obligations or available parent transactions. Returned nested lists and byte components are detached and immutable. Separate method calls use separate snapshots.

Every call opens the existing source with `OpenMode.readOnly`, verifies `query_only=ON`, uses zero busy wait and closes its short read transaction/handle before completion. The full pinned bark0.8.1/schema42 table/index/FK guard and independently configured regtest identity are checked before any row absence is returned. JSON and BLOB lengths are checked in SQL before materializing payloads in the same snapshot; JSON limits count UTF-8 bytes, not characters. Limits are1MiB per JSON/child/component field and256 nested references. Oversized or malformed typed data refuses the whole lookup. These limits are not a hard SQLite-process memory or latency bound; read locks can briefly delay rollback-journal writers.

No archive database, material duplication service, timer, filesystem listener, native wallet/key/signing/network call, source SQL write, hidden retry or complete-chain reconstruction is installed. Bark reconstructs parent transactions from its protocol components; this reader deliberately does not. A four-byte fingerprint is a checked discriminator, not cryptographic authentication. Existing files produced by the retired archive runner are left untouched; removing that code does not delete user data.

## Never-signed Board observations

The optional privileged `ArkBoardAbandonmentPort` can attest an exact irreversible host-journal never-signed tombstone. The client matches account, operation, native pending Board funding txid, original funding tuple and quote amounts before classifying an otherwise unknown VTXO as `abandonedBoard`. Such an entry is never eligible to spend or renew. Its verified Board-only pending contribution is excluded without subtracting Lightning or other pending funds. Missing, failed or mismatched proof keeps the unknown inventory stale. The nullable `pendingBoardBalance` component is independently observed; an absent component is not zero. A unique current native pending-Board row must provide the exact VTXO-to-funding link. If a review is abandoned before that link is recorded, or the link disappears before classification, a host never-signed receipt alone cannot classify the retained unknown; it remains stale. Matching only amount and expiry is insufficient.

Classification retains the native pending Board, operation and custody obligations. It does not cancel a Bark action or promise that Bark will forget it: the pinned implementation can start its own exit near expiry. No native deletion or abandonment API is invoked. Other stale observations, incomplete recovery and stage failures remain authoritative barriers.
