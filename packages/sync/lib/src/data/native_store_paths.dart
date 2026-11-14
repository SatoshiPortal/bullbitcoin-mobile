import 'package:primitives/primitives.dart';

import '../domain/native_network_policy.dart';
import '../domain/transaction_sync_failure.dart';
import '../domain/wallet_key.dart';

/// Legacy native location, without IO or normalization of the supplied root.
///
/// The id is encoded as UTF-16 code units, NOT UTF-8 bytes. Liquid receives a
/// root beneath which LWK manages its network and descriptor directories.
/// Historical ids encode the network. Bitcoin regtest reserves the `:regtest`
/// suffix because its derivation origin shares testnet coin type 1. The entire
/// id is encoded, so existing paths remain byte-identical.
/// Pass getApplicationDocumentsDirectory().path verbatim as documentsDirectory.
String nativeWalletStoragePath(String documentsDirectory, WalletKey key) {
  if (key.network.env == NetworkEnv.regtest &&
      (!key.id.endsWith(':regtest') || key.id.length == ':regtest'.length)) {
    throw ArgumentError('Regtest storage requires a distinct wallet id');
  }
  final hexId = key.id.codeUnits
      .map((unit) => unit.toRadixString(16).padLeft(2, '0'))
      .join();
  final suffix = switch (key.network) {
    BitcoinNetwork.mainnet ||
    BitcoinNetwork.testnet ||
    BitcoinNetwork.regtest => '_bdk_dart',
    LiquidNetwork.mainnet ||
    LiquidNetwork.testnet ||
    LiquidNetwork.regtest => '',
    BitcoinNetwork.signet => throw ArgumentError('Unsupported storage network'),
  };
  return '$documentsDirectory/$hexId$suffix';
}

/// Package stores, separate from native stores and the app's Drift database.
String _directory(String documentsDirectory) =>
    '$documentsDirectory/transaction_sync';

String revisionStorePath(String documentsDirectory) =>
    '${_directory(documentsDirectory)}/revisions.sqlite';

/// Present while quarantined revision metadata awaits its adoption pass.
String recoveryMarkerPath(String documentsDirectory) =>
    '${revisionStorePath(documentsDirectory)}.recovery';

String spendGateStorePath(String documentsDirectory) =>
    '${_directory(documentsDirectory)}/spend_gate.sqlite';

/// The lock is named after the native store it protects, so two keys that
/// resolve to the same store share one lock. An unsupported key is refused
/// before any path is derived.
Result<String, TransactionSyncFailure> writerLockPath(
  String documentsDirectory,
  WalletKey key,
) {
  final failure = nativeKeyFailure(key);
  if (failure != null) return Err(failure);
  final store = nativeWalletStoragePath(documentsDirectory, key);
  final name = store.substring(store.lastIndexOf('/') + 1);
  return Ok('${_directory(documentsDirectory)}/locks/$name.lock.sqlite');
}
