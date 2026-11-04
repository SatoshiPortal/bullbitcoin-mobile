import 'package:primitives/primitives.dart' show RelativeFee;

import 'wallet_metadata.dart';

/// Ephemeral signing capabilities supplied by the host's secret store.
/// Callers hold the wallet source session throughout these operations.
abstract interface class WalletSigningPort {
  Future<String> signPsbt(String psbt, {required String walletId});
  Future<String> bumpFee({
    required String walletId,
    required String txid,
    required RelativeFee newFeeRate,
  });
  Future<String> signPset(String pset, {required WalletMetadata metadata});
}
