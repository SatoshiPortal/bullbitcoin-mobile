import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/coins/domain/coins_error.dart';

/// Unfreezes the given outpoints for a wallet. The core repository only ever
/// deletes `origin = 'user'` rows, so a user can never unfreeze a system lock.
/// Maps any failure to [CoinsError.unfreezeFailed].
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
