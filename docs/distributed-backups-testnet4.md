# Testnet4 prototype verification

Tested on 2026-09-07 on branch `distributed-resiliant-backups`. The existing Bitcoin recovery implementation was used unchanged. The test harness now accepts a network, Electrum endpoint and expected funded balance; the standalone entrypoint accepts the same network setting.

## Single-transaction revision

The latest user constraint is one new transaction, one OP_RETURN, and the complete encrypted descriptor. [The new transaction](https://mempool.space/testnet4/tx/6ad5fb1579febda9797d1e9612d66733845a875c2689d63216e835c361e1c74a) is 1,687 vbytes (1,768 serialized bytes, weight 6,745), down from generation 1's 1,773 vbytes. Its 1,469-byte BIP138 payload is byte-for-byte identical to the original, including the full 1,262-byte descriptor after decryption. No template, compression, encryption, or recipient-mask change was made.

The transaction spends one existing funding-wallet output. It contains one zero-value OP_RETURN, three 1,000-sat discovery outputs, and 24,532 sats of change to the same funding owner. The fee is 3,376 test sats. Removing the two test-only P2TR vault payments saves exactly 86 vbytes; there is no separate funding transaction. This is a measured reduction under the retained format, input, marker and change constraints, not a proof of a universal minimum across other formats or spending arrangements.

Public Electrum history discovery through each marker and independent Python decryption with all three xpubs passed for this exact new transaction. It was unconfirmed when checked. The raw transaction, measurements, histories and independent results are in `distributed-backup-evidence/testnet4/single-transaction/`.

The emulator test accepts `--dart-define=DISTRIBUTED_EXPECT_TXID=6ad5fb1579febda9797d1e9612d66733845a875c2689d63216e835c361e1c74a` to require this exact transaction in every cosigner's real marker history, fetch it and decrypt its full descriptor. That assertion is separate from the UI recovery assertions: the UI deduplicates identical descriptors and may display the older copy. App composition receives no known txid or descriptor fixture.

Android verification passed on `emulator-5582`: all three exact-publication fetch/decrypt assertions, six UI wallet restores with 3,000 sats and persisted/reopened SQLite, and three live Nostr fetches. The first test ran for 58 seconds after build/install; a second complete emulator run passed the same twelve assertions after the reviews. Sixteen BIP138/Bitcoin codec regression tests passed (fixture export skipped), and whole-project analysis passed after correcting a test-only key-type mismatch. The app codecs and runtime code are unchanged; these results do not claim a new full-suite run or a new audit of the underlying native dependencies.

Seven review lenses and a cross-review pass found no remaining issues in this change. The two actionable gaps were corrected: testing the exact new transaction despite UI deduplication, and stale publication/size documentation. Security review checked unchanged authenticated payload bytes, ownership of funding change, bounded fees and public test-only inputs. Existing prototype privacy, authenticity and native network limits remain unchanged.

## Original published transactions

The user supplied 50,000 testnet4 sats to the dedicated funding wallet. Two public synthetic BullVault generation policies were backed up:

- [Generation 0](https://mempool.space/testnet4/tx/7f0bf8e3c6428b0fb82fea33b3d67399b6308fe30d921d1de18b42831aecc901): 1,771 vbytes, 3,544-sat fee.
- [Generation 1](https://mempool.space/testnet4/tx/d8ea3b6dd6498e1cd10866697a2b7334cf07b9ea61a6079ac88d5ca94f75b660): 1,773 vbytes, 3,548-sat fee.

Each transaction has seven outputs: one OP_RETURN containing the complete BIP138 file, three 1,000-sat discovery outputs, two test-only vault payments (1,000 sats receive and 2,000 sats change), and funding change. The two vault payments prove restored balances; they are not required by the backup protocol. The final funding change is 30,908 test sats. The dedicated offline Core wallet and a private local wallet backup preserve its signing key; no funding private key is checked into this repository.

Both transactions were still unconfirmed at the recorded verification time. These results prove real public testnet4 mempool discovery and recovery, not confirmed archival availability. The latest observed status is recorded in `distributed-backup-evidence/testnet4/status.json`.

## Observed results

- Public Electrum: `ssl://blackie.c3-soft.com:57010`, certificate validation enabled. The standard first-address history and raw-transaction APIs returned both backups for all three account xpubs. No local Electrum proxy or custom index was used.
- Host: all six cosigner/generation combinations recovered the expected policy, synchronized 3,000 test sats, persisted SQLite, and successfully reopened the wallet. The test completed in 27 seconds.
- Android: all six combinations passed through actual input, fetch and restore buttons on `emulator-5582`. Wallet identities matched the host results. The same run opened the existing Nostr screen and fetched backups for all three xpubs. Runtime was 56 seconds after build/install.
- Independent Python cryptography: both published BIP138 payloads decrypted under all three cosigner xpubs. Separately fetched transaction bytes matched the prepared transaction and the extracted OP_RETURN bytes exactly.
- Verification: seven codec/fixture-export tests passed, and whole-project analysis found no issues. The inherited full repository gate of 3,321 tests is documented separately in `distributed-backups-prototype.md`; it was not rerun as evidence for this testnet4 extension.

The first host attempt found no candidates because acceptance by the mempool.space broadcast API had not yet propagated the unconfirmed transactions to the queried Electrum nodes. Broadcasting the funding parent followed by both backups directly through standard Electrum succeeded on mempool.space and blackie.c3-soft.com; address histories then contained both transactions. That original publication helper sent the package directly through Electrum. The current helper broadcasts only the single newly prepared backup transaction; its funding parent must already be available to the server. This propagation failure is not counted as a passing recovery test. The first Android invocation could not find the stopped emulator; the successful run followed a fresh boot of the dedicated AVD.

Public synthetic cosigner keys are intentionally recoverable by anyone reading the fixture source. Use test coins only. The existing limits still apply: fixed first 200 receiving and 200 change addresses, watch-only restoration, public linkage through discovery outputs, and native Electrum response/deadline/cancellation limitations. Successful testing of this public server is not a hostile-server security guarantee.

## Repeat recovery

Existing published transactions can be fetched without funding or publishing again. Run Flutter commands sequentially and use the repository FVM/toolchain setup.

```bash
fvm flutter test --no-pub test/features/bullvault/bitcoin_backup_live_test.dart --dart-define=DISTRIBUTED_LIVE=true --dart-define=DISTRIBUTED_NETWORK=testnet4 --dart-define=BACKUP_ELECTRUM=ssl://blackie.c3-soft.com:57010 --dart-define=DISTRIBUTED_BALANCE_SATS=3000 --dart-define=BACKUP_EVIDENCE=/tmp/testnet4-host.json --reporter expanded
fvm flutter test --no-pub integration_test/distributed_backups_prototype_test.dart -d emulator-5582 --flavor beta --dart-define=DISTRIBUTED_LIVE=true --dart-define=DISTRIBUTED_NETWORK=testnet4 --dart-define=BACKUP_ELECTRUM=ssl://blackie.c3-soft.com:57010 --dart-define=DISTRIBUTED_BALANCE_SATS=3000 --dart-define=DISTRIBUTED_NOSTR_LIVE=true --reporter expanded
fvm flutter build apk --debug --flavor beta --target tools/distributed_backups_prototype_app.dart --target-platform android-x64 --dart-define=DISTRIBUTED_NETWORK=testnet4 --dart-define=BACKUP_ELECTRUM=ssl://blackie.c3-soft.com:57010
```

The standalone APK is an Android x86-64 beta debug build. It was installed and cold-launched outside the integration runner; UI inspection verified the recovery screen and public endpoint. Its SHA-256 and build settings are recorded in `distributed-backup-evidence/testnet4/standalone.json`. It opens testnet4 recovery against the public Electrum endpoint. Copy any xpub from `distributed-backup-evidence/testnet4/publication.json`. Public synthetic keys or vault coins may later be spent by anyone; the expected 3,000-sat assertion intentionally detects that change instead of silently weakening the test.

## Publication setup for another test

This is a development tool using Core as an offline signer and mempool.space to obtain funding UTXOs and raw parent transactions. Recovery itself uses only Electrum. Initialize a new, separately labeled Core container and wallet once:

```bash
docker run -d --name distributed-backup-testnet4-core --label bull.distributed-backup-testnet4=true --network none bitcoin/bitcoin@sha256:68b927b6a2d3b019ce7655f3fd0eb9a4c7011310886ebc7890e5246c16df5ec6 bitcoind -testnet4 -server=1 -networkactive=0 -listen=0 -dnsseed=0 -rpcuser=backup -rpcpassword=prototype -fallbackfee=0.00001
docker exec distributed-backup-testnet4-core bitcoin-cli -testnet4 -rpcuser=backup -rpcpassword=prototype createwallet distributed-testnet4
docker exec distributed-backup-testnet4-core bitcoin-cli -testnet4 -rpcuser=backup -rpcpassword=prototype -rpcwallet=distributed-testnet4 getnewaddress distributed-backup-testnet4 bech32
```

For a fresh publication setup, fund that address with at least 20,000 testnet4 sats. The current helper publishes only the final policy in the fixture and creates no vault payments. The fixed-balance recovery commands above rely on the original funded fixture transactions and are not a fresh-chain funding recipe. The signing wallet generates its own private key inside Core. The helper validates the container label, testnet4 genesis, funding transaction identity/value/script, ownership, and Core-derived discovery addresses. Each publication fee is capped at 4,000 test sats; unused funds return to the funding wallet. Prepared transactions are saved before broadcast and the helper refuses to overwrite an existing preparation file.

```bash
fvm flutter test --no-pub test/features/bullvault/data/bitcoin_backup_codec_test.dart --dart-define=DISTRIBUTED_NETWORK=testnet4 --dart-define=BACKUP_FIXTURE=/tmp/testnet4-fixture.json --reporter expanded
python3 tools/distributed_backup_testnet4.py prepare /tmp/testnet4-fixture.json /tmp/testnet4-publication.json
python3 tools/distributed_backup_testnet4.py broadcast /tmp/testnet4-publication.json
```

Repeat recovery using the existing publications without spending more test coins. The current backup-only publisher does not fund the vault receive/change addresses; marker payments do not affect those vault balances. The helper rejects multi-transaction preparation records when broadcasting. Keep the dedicated signing wallet if its returned test coins are still needed.

## Payload and size measurements

`distributed-backup-evidence/testnet4/descriptor-generation1.txt` is the exact decrypted 1,262-byte UTF-8 descriptor from the second transaction. Its decrypted content is the six-byte prefix `01 01 7c fd ee 04` followed by those descriptor bytes. The complete encrypted BIP138 file is 1,469 bytes.

Removing the two test-only P2TR payments saves 86 vbytes, as verified by the new transaction above. The previously measured BIP388 template alternative was abandoned after the user required the full encrypted descriptor. The prototype continues to write the same BIP138 BIP380 content. Its existing recipient padding and authenticated encryption are retained.
