import 'dart:typed_data';

import 'models.dart';

/// Resolves the private key that can spend a given output. Implemented by the
/// consuming app (e.g. via BDK's `derivationOfSpk` + `DescriptorSecretKey`);
/// this package never touches key material directly, keeping it pure Dart and
/// free of any wallet/FFI dependency.
///
/// The returned bytes are the raw 32-byte secp256k1 private key. Implementers
/// must treat the value as ephemeral: derive at point of use, never log,
/// cache, or persist it.
abstract interface class PrivateKeyResolver {
  /// The 32-byte private key that can sign for [scriptPubKey], or throws if
  /// the script is not one this wallet controls.
  Future<Uint8List> keyForScript(Uint8List scriptPubKey);
}

/// Looks up the current on-chain state of an outpoint, so verification can
/// confirm a proven UTXO actually exists, matches what the proof claims, and
/// is unspent. Implemented by the consuming app (e.g. over Electrum).
///
/// Optional: when not supplied to verification, the check is offline-only and
/// per-UTXO [OnChainStatus] stays [OnChainStatus.notChecked].
abstract interface class ChainLookup {
  /// The on-chain output at [outpoint], or `null` if it does not exist.
  Future<ChainUtxo?> lookup(ProofOutpoint outpoint);
}
