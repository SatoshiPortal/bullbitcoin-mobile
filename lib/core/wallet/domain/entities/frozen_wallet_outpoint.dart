import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';

/// A persisted user freeze with its exact wallet attribution.
///
/// An empty [walletId] is intentional: it represents an imported freeze whose
/// wallet could not be identified. The outpoint remains globally enforceable
/// when a live wallet owns it, but no wallet attribution is guessed.
final class FrozenWalletOutpoint {
  final String walletId;
  final String txId;
  final int vout;

  factory FrozenWalletOutpoint({
    required String walletId,
    required String txId,
    required int vout,
  }) {
    final normalizedTxId = txId.toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalizedTxId)) {
      throw ArgumentError.value(txId, 'txId', 'must be 64 hexadecimal chars');
    }
    if (vout < 0 || vout > 0xffffffff) {
      throw ArgumentError.value(vout, 'vout', 'must be an unsigned 32-bit int');
    }
    return FrozenWalletOutpoint._(
      walletId: walletId,
      txId: normalizedTxId,
      vout: vout,
    );
  }

  const FrozenWalletOutpoint._({
    required this.walletId,
    required this.txId,
    required this.vout,
  });

  bool get isAttributed => walletId.isNotEmpty;

  Outpoint get outpoint => (txId: txId, vout: vout);
}
