# Labels

`package:labels/labels.dart` provides label persistence and BIP-329 import and export.

```dart
final labels = Labels.open(database: database, sync: getSync, openWallet: openWallet);
final all = await labels.fetch();
final matching = await labels.fetch(reference: txid);
final suggestions = await labels.suggestions(type: LabelType.address);
final saved = await labels.store(NewLabel.addr(address: address, label: note));
final removed = await labels.trash(labelId);
```

An empty match is a successful read. Consumers decide whether a read failure should preserve existing UI state or fall back to empty enrichment. Receive suggestions use the address filter because a BIP-21 message is visible to the payer.

The sync and wallet callbacks are resolved when BIP-329 operations need freeze data. The app composes the reserved-address and Payjoin adapters through `package:labels/setup.dart`.
