# Distributed resilient backups prototype

Branch: `distributed-resiliant-backups`, based on `prototype/bullvault-bip138-nostr` at `bda56ac83`.

Public testnet4 follow-up: [transactions, host/Android results, exact payload and repeat commands](distributed-backups-testnet4.md).

## Locked prototype scope

The user-approved Bitcoin layout is one transaction containing one complete shared BIP138 backup in OP_RETURN and three ordinary outputs to `wpkh(cosigner_account_xpub/0/0)`, plus funding change when needed. Repeated revault backups reuse these discovery addresses. Recovery uses only one account xpub or single-key descriptor and a configured standard Electrum server. It queries script history, downloads candidate transactions, validates transaction identity and discovery output membership, decrypts locally, and retains every distinct valid policy.

BullVault owns protocol parsing and recovery rules in data/domain, with thin usecases and cubit and a separate prototype screen. Reuse the existing BIP138 codec, canonical account parser, BDK descriptor/transaction parsing, ElectrumSocketConnector and ElectrumConnection, Bull UI/localization, and screen privacy. Extract the existing descriptor parsing into a shared BullVault data helper; it is shared between two transports within the same feature, not a new core business module. No new feature dependency or facade is needed. Legacy Electrum folders remain unchanged.

Restore means a dedicated prototype SQLite-backed BDK watch-only wallet, synchronization of the first 200 receiving and 200 change addresses, and reopening, without production wallet metadata or signing keys. Explicit network selection distinguishes testnet, signet and regtest account keys. Prototype composition roots remain separate from production main/router/settings; existing metadata backup and Nostr encryption remain unchanged. Publication tests use synthetic keys and an isolated real Bitcoin Core regtest node plus stock electrs. No real funds are used.

## Work checklist

- [x] Create isolated branch/worktree and inspect current source/API contracts.
- [x] Seven planning contributions and reconciliation of architecture, evidence, Flutter, UX, simplicity, scope and compliance.
- [x] Implement shared parsing, Bitcoin payload/discovery and bounded Electrum retrieval.
- [x] Implement explicit watch-only restore/sync/reopen and runnable prototype UI.
- [x] Publish two distinct synthetic revault backups; fund both recovered wallets; spend all three first-generation discovery outputs.
- [x] Test all three xpubs against real Electrum in the Android emulator.
- [x] Run security, architecture, evidence, Flutter, UX, simplicity, scope and compliance reviews; fix and cross-review.
- [x] Run full checks and Nostr regression; repeat emulator test after fixes.
- [x] Build runnable APK and commit functional prototype.

## Review and verification method

Implement one coherent prototype slice with internal protocol, transport and UI checkpoints. Use meaningful deterministic tests for each checkpoint, then the seven-agent review/fix/cross-review gate before completion. Run Flutter build/test commands sequentially because native asset manifests are shared within a checkout. Required repository gate: `make checks`; integration and final standalone builds follow the repository FVM rules. Tests must prove the same transaction and same ciphertext recover under all three keys, distinct funded revault policies survive discovery, spent discovery outputs remain in history, and restored SQLite wallets reopen.

## Security and recovery limits

An account xpub is a recovery capability. Raw BIP138 uses account x-only public keys for recipient recovery and exposes deterministic recipient masks; the Nostr prototype's outer encryption hides those masks. Reused discovery addresses publicly link backup transactions and associate the three cosigners. No promise of unlinkability is made. The displayed balance covers only the bounded prototype scan; later address indices may hold additional funds. Cancelling suppresses the UI result but a native sync already in progress can finish local persistence; restores are serialized to prevent concurrent SQLite writes. The fixed address count does not bound native Electrum response allocation or total sync duration: the pinned native client uses inactivity timeouts and unbounded response-line allocation. Use a trusted controlled Electrum server for prototype restoration. Hard response/time limits and interruptible native sync remain necessary before production integration; the Dart discovery transport already enforces its own response and total-search limits. AEAD and account membership checks detect corruption and unrelated candidates, but do not authenticate the intended vault policy against another holder of the account public information.

Electrum supplies candidate history; recomputing a txid verifies transaction bytes, not chain inclusion or completeness. No stock history pagination is assumed. Limits, timeouts, cancellation and failures must not appear as a completed empty search. Archived history remains necessary for recovery decades later, and returned policies need independent verification before receiving funds. This is a prototype pinned to the existing BIP138 draft, not a finalized protocol endorsement.

## API evidence

Verified 2026-09-07 against the pinned local `bdk_dart` source (`fbf8952ed7056c9663e4bd47dddc8b4994580532`): native transaction parsing, `TxBuilder.addData`, `addRecipient`, `Wallet` SQLite persistence, and Electrum sync are present; no direct script-history binding exists. Standard history and raw-transaction RPC definitions: https://electrumx.readthedocs.io/en/latest/protocol-methods.html . The existing Nostr profile and upstream BIP138 pin are documented in `bip138-nostr-prototype.md`.

## Run the prototype

Use the repository's usual dependency/code-generation setup first (`make deps`, `make build-runner`, `make translations`). Run Flutter tests/builds sequentially in this checkout. The Android test uses a dedicated emulator, not a personal wallet installation.

```bash
python3 tools/distributed_backup_regtest.py start
fvm flutter test test/features/bullvault/data/bitcoin_backup_codec_test.dart --dart-define=BACKUP_FIXTURE=/tmp/distributed-backup-fixture.json
python3 tools/distributed_backup_regtest.py publish /tmp/distributed-backup-fixture.json /tmp/distributed-regtest-evidence.json
adb -s emulator-5582 reverse tcp:51401 tcp:51401
fvm flutter test test/features/bullvault/bip138_live_relay_test.dart --dart-define=BIP138_LIVE=true --reporter expanded
fvm flutter test integration_test/distributed_backups_prototype_test.dart -d emulator-5582 --flavor beta --dart-define=DISTRIBUTED_LIVE=true --dart-define=DISTRIBUTED_NOSTR_LIVE=true --reporter expanded
fvm flutter build apk --debug --flavor beta --target tools/distributed_backups_prototype_app.dart --target-platform android-x64
```

The publication tool starts only its labeled dedicated containers, uses a Core node on an isolated internal Docker network, and exposes stock electrs only on host loopback port 51401. A separate bridge permits that loopback mapping; no custom Electrum methods or unspendable-output indexing are enabled. The two images are pinned by immutable repository digests in the script. The evidence records the matching local content IDs used for this run. `python3 tools/distributed_backup_regtest.py stop` stops only the two labeled prototype containers and preserves their chain/index state. Existing Boltz/Bark services are not used or modified.

Publication creates two different BullVault generation policies using public synthetic test keys, one shared BIP138 file per policy, three 1,000-sat discovery outputs per transaction, and change. Core independently derives all three discovery addresses. It funds each vault with 100,000 sats on receive index 0 and 200,000 sats on change index 0, spends the first generation's three discovery outputs, mines confirmations, and checks history/UTXO behavior through Electrum. Use a fresh fixture chain for a new publication run: re-funding the same policies would change the expected 300,000-sat test balance. The tool refuses to overwrite an existing evidence file.

The runnable APK opens a recovery-only screen with explicit Bitcoin network and Electrum endpoint controls. Paste one of the public xpubs in `distributed-backup-evidence/regtest.json`, fetch, then select either policy's watch-only restore action. Its Nostr button opens the existing recovery-only Nostr harness. No publishing seed or known backup payload is passed into Bitcoin recovery. On a physical device use an appropriately reachable configured Electrum endpoint; `127.0.0.1:51401` on the emulator works only after the documented `adb reverse`.

The first-address convention always means `wpkh(account_xpub/0/0)`, including when a supplied single-key descriptor has a different suffix. A descendant xpub is not interchangeable with the account xpub. Account origin fields and public serialization aliases are normalized by the existing parser. Marker output values are test construction choices, not part of discovery; spending the outputs does not erase their transaction history.

## Review record and observed evidence

Seven planning contributions and seven implementation reviews covered architecture, evidence/security, Dart/Flutter, UX, simplification, deletion/scope and AGENTS compliance. All seven performed cross-review. Final focused security, Flutter and simplification reviews checked the runtime fixes. Material fixes include independent OP_RETURN rejection, expected spender-only history handling, explicit search bounds, consistent TLS/SOCKS normalization, isolate capture separation, native resource cleanup, typed result validation and honest watch-only/scan-limit copy.

The first repository test exposed an unsendable cancellation completer captured by the crypto closure; moving that closure into a static helper fixed it. The first real restore exposed unsupported `server.features` on stock electrs 0.4.1; genesis verification now hashes `blockchain.block.header(0)` locally and compares it with BDK's expected genesis. Neither failed run is counted as successful evidence.

`distributed-backup-evidence/regtest.json` records the actual transactions, shared payloads, three xpubs, marker spend and pinned node/indexer versions. `host.json` records all six successful combinations of three cosigners and two policies, including stable wallet identities, independently funded addresses, synchronized 300,000-sat balances and successful SQLite reopening. `independent.json` records decryption of both payloads under all three keys using the existing Python cryptography verifier, independent of the Dart codec. All checked-in keys, descriptors and transactions in these artifacts are public synthetic regtest fixtures and must never be funded on public networks.

Final repository checks passed: whole-project analysis, Bull UI boundary, Dart fix dry-run, formatting, 3,145 app tests and 176 package tests (3,321 total). Three opt-in tests were skipped in the default suite; fixture export, host Bitcoin recovery and public-relay Nostr recovery are run separately with their documented defines.

Both Android emulator runs passed all six combinations of three xpubs and two funded policies, including persistence and reopening. The second run followed the final reviews and fixes and also opened the Nostr screen from the Bitcoin prototype, then fetched this run's freshly published events using all three xpubs. `distributed-backup-evidence/emulator.json` records both runs and their matching Bitcoin wallet/transaction identities; `nostr.json` records public relay acknowledgements and host recovery identities. The final Android test completed in 44 seconds after its build.

The standalone Android x86-64 beta debug APK was built from `tools/distributed_backups_prototype_app.dart`, installed on the dedicated emulator, and cold-launched outside the integration test runner. Its identity and SHA-256 are recorded in `distributed-backup-evidence/standalone.json`; the local build output is `build/app/outputs/flutter-apk/app-beta-debug.apk`. This emulator APK is separate from production settings integration and is not an ARM device release.

A separate standalone smoke check entered the exact synthetic everyday xpub using paced keyboard input, fetched through real Electrum, and verified that both recorded backup transaction IDs and a decrypted policy with its watch-only restore action appeared. Rapid ADB keyboard injection dropped characters in this debug emulator; those attempts were rejected by the smoke-check input assertion and were not counted as recovery passes.
