# Ark

Pure Dart protocol boundary for bark. `ark.dart` publishes accounts, immutable observations, reviewed quotes, journalled operations, receive requests and the `ArkClient` interface. `ark_setup.dart` is the privileged composition surface: it accepts a scoped dedicated-child provider, a host public-transaction-codec verifier, execution policy and stage budget. It must not be re-exported by an ordinary feature facade.

The exact native dependency is `bark_bitcoin 0.27.0+bark-0.8.1`. Native constructors and calls live only in `bark_native_opener.dart`. The adapter opens the internal on-chain wallet and Ark wallet under one account lock, with `runDaemon:false`. It never attaches bark's logger, receives the parent seed, signs a BULL source transaction or broadcasts a source-wallet funding PSBT.

## Admission and recovery

The host must register a durable parent obligation under parent-custody admission before calling `create`. Lock order is parent admission, package lifecycle admission, account writer, short metadata transaction. The child provider executes inside the account writer and must not reacquire parent admission. A durable obligation protects subsequent scoped derivation. Source-wallet funding admission happens separately after all Ark native locks are released.

Projection reads never open bark. Native stages await their admitted future before closing handles and releasing SQLite rollback-journal locks. A budget revokes only the next stage. `backgroundExisting` refuses creation, missing or incompatible metadata and native datadirs; it can synchronize and delegate renewal but cannot submit foreground exits/claims or receive/payment requests. The host supplies background eligibility independently of whether Ark is offered as a new payment route.

A quote binds account observation, configuration generation, exact chain provider, fee, selection, destination and review validity. Exit progression also binds the complete live exit set, fixed integer fee rate and confirmed internal reserve coin set/exposure. It authorizes one account-wide attempt. Raw addresses are only syntactically classified by `isArkAddress`; authoritative parsing and estimation stay inside the writer.

Irreversible calls follow durable admission. An exception after admission leaves an unknown operation, never an automatic spend retry. `read` exposes journalled operations after restart; `synchronize` reconciles positive native evidence. Provider absence never proves rejection. Claims use explicit ids, inspect actual/skipped ids, extract the signed transaction, verify PSBT input values/final witnesses plus transaction facts through the host port, debit the cumulative exit authorization and persist the exact signed bytes/txid before broadcast. Skipped ids retain only the remaining fee allowance.

Boarding is `quote(board)` -> `boardFunding(quoteId, operationId)` -> host atomic funding reservation -> `registerBoard` with the exact journalled tuple and unfinalised native-segwit PSBT -> host signing and guarded broadcast. `confirmQuote` cannot board. Registered boards follow an exact unsigned txid; do not change that txid through a generic fee bump. Pending/unknown funding remains an obligation until positive settlement or a separately reviewed proof of conflict/never-signed state. No abandon or cancellation guarantee is exposed. Funding approaching its tuple expiry requires urgent host attention; late confirmation can expose coins to server expiry clauses.

## Observations and privacy

Unknown balances/heights/counts are nullable. A stale or incomplete observation is never an unfunded account. Per-exit details, pending boards, operations and VTXO-section completeness support recovery and expiry reminders. Missing formerly live VTXOs or a regressed tip cannot clear an existing warning. A delegated round remains pending until positive replacement evidence; it is not a renewed balance.

Primary and optional fallback Esplora endpoints are configured explicitly. Only a transport failure before any HTTP response/native admission permits fallback. HTTP rejection, malformed data, a different genesis or a regressed tip does not. A reviewed or uncertain operation stays bound to its selected endpoint. Direct Ark/Esplora traffic exposes IP addresses and wallet activity to those providers; this adapter has no Tor transport.

## Verification

Use the repository's pinned FVM toolchain and make targets for integrated checks. The package tests cover public contracts, real SQLite persistence/exclusion across processes, abrupt process death, lifecycle admission through a native fake, quote/idempotency/claim policies and local HTTP fallback discrimination. Native-fake tests do not establish actual bark signing, persistence or network behavior. Native runtime and end-to-end board/payment/renewal/exit proof remain separate integration gates, as do Android background and iOS lifecycle validation. Bark's hook requires its own pinned Rust 1.90.0 and protoc; another dependency's Rust environment override must not replace that compiler.

## Already signed claim delivery

`rebroadcastClaim(operationId, expectedTxid)` may run automatically in foreground or `backgroundExisting` for an existing verified signed claim. It uses the account writer and captured Esplora directly, without child derivation, Secrets access, a native wallet, new signing, quote freshness or another authority debit. Other background submissions remain refused. The host runs this lane independently of keyed renewal and supplies protected existing-account admission even when new Ark routing is off.

Each invocation persists its attempt separately from immutable signed evidence and performs at most one POST of exactly the saved raw transaction. Policy and budget are rechecked after verification/preflight and immediately before transport. The POST has its own total15-second bound and128-byte reply limit, disables redirects and awaits owned HTTP abort/cleanup. Preflight retains its existing per-request/inactivity bounds; the entire task is not claimed to have a15-second deadline. A matching reply means pending, not confirmed. Failure or an uncertain reply returns uncertainty and retains signed evidence/debit for a later scheduled invocation. A result-persistence failure may leave the stored operation pending or unknown; neither releases protection or changes the signed transaction. Positive journalled confirmation/conflict suppresses delivery; absence of optional chain evidence does not create new signing or release authority.
