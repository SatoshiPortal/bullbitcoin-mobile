# Labels

`package:labels/labels.dart` provides label persistence and BIP-329 import and export.

```dart
final opened = await Labels.open(file: file, admission: admission, listAttributedFreezes: listFreezes, freezeAttributedOutpoints: freeze, openWallet: openWallet, readInSession: inventory.readInSession);
if (opened case Err(:final failure)) return Err(failure);
final labels = (opened as Ok<Labels, LabelFailure>).value;
final all = await labels.fetch();
final matching = await labels.fetch(reference: txid);
final suggestions = await labels.suggestions(type: LabelType.address);
final saved = await labels.store(NewLabel.addr(address: address, label: note));
final removed = await labels.trash(labelId);
```

An empty match is a successful read. Consumers decide whether a read failure should preserve existing UI state or fall back to empty enrichment. Receive suggestions use the address filter because a BIP-21 message is visible to the payer.

The sync and wallet callbacks are resolved lazily. Wallet-owned outpoint reads for freeze validation run in the foreground inventory session from wallet resolution through publication of the loaded outpoints. This read guard does not authorize the subsequent freeze write. The app composes the reserved-address and Payjoin adapters through `package:labels/setup.dart`.

Labels owns one encrypted schema-1 store for labels and user-frozen outpoints. The foreground coordinator imports raw rows, verifies them and preserves the labels AUTOINCREMENT high-water state in the same transaction as its sole readiness receipt. A missing receipt, conflicting preexisting state, invalid sequence or unavailable key blocks opening. The historical database and migrations are retained for unported owners; no legacy deletion occurs.

`setupLabels` registers the opened capability and its owner-built freeze/reservation ports. Sync spending checks, BIP-329 operations and Payjoin labels share that same authority. Unavailable freeze storage remains a failure, never an empty set. The native worker uses Flutter's platform messenger for the Secrets key capability; lifecycle admission remains held until native close acknowledgment. Test-only injected construction is available exclusively from `testing.dart`.
