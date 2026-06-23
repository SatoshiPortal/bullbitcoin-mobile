import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/coins/domain/coins_error.dart';

/// Unfreezes the given outpoints. Persisted freezes are always user freezes
/// (system/payjoin locks are derived live, never stored), so unfreezing is safe
/// by construction. Maps any failure to [CoinsError.unfreezeFailed].
class UnfreezeUtxosUsecase {
  UnfreezeUtxosUsecase({required this._walletUtxoRepository});

  final WalletUtxoRepository _walletUtxoRepository;

  Future<void> execute({
    required String walletId,
    required List<Outpoint> outpoints,
  }) async {
    try {
      await _walletUtxoRepository.unfreezeUtxos(
        walletId: walletId,
        outpoints: outpoints,
      );
    } catch (_) {
      throw const CoinsError.unfreezeFailed();
    }
  }
}
