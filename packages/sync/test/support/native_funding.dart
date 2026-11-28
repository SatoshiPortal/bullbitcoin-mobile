import 'dart:typed_data';

import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:sync/src/data/native_store_paths.dart';
import 'package:sync/src/data/write/datasources/bdk_wallet_store_datasource.dart';
import 'package:sync/sync.dart';

export 'package:sync/src/data/native_store_paths.dart'
    show nativeWalletStoragePath, revisionStorePath;

/// Persists the unconfirmed 54321-sat fixture in the native Bitcoin store.
void fundBitcoinNativeStore(String directory, BitcoinWalletDescriptor bitcoin) {
  final bdkStore = BdkWalletStoreDatasource.load(
    nativeWalletStoragePath(directory, bitcoin.key),
    bitcoin,
  );
  try {
    final address = bdkStore.wallet
        .peekAddress(keychain: bdk.KeychainKind.external_, index: 0)
        .address;
    final script = address.scriptPubkey().toBytes();
    address.dispose();
    final amount = ByteData(8)..setUint64(0, 54321, Endian.little);
    final raw = BytesBuilder()
      ..add([2, 0, 0, 0, 1])
      ..add(List.filled(32, 0x11))
      ..add([0, 0, 0, 0, 0, 255, 255, 255, 255, 1])
      ..add(amount.buffer.asUint8List())
      ..add([script.length])
      ..add(script)
      ..add([0, 0, 0, 0]);
    final tx = bdk.Transaction(transactionBytes: raw.toBytes());
    try {
      bdkStore.wallet.applyUnconfirmedTxs(
        unconfirmedTxs: [bdk.UnconfirmedTx(tx: tx, lastSeen: 1)],
      );
      bdkStore.persist();
    } finally {
      tx.dispose();
    }
  } finally {
    bdkStore.close();
  }
}
