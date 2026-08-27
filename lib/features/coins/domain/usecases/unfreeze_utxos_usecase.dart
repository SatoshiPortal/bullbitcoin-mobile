import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/coins/domain/coins_failure.dart';

/// Unfreezes the given outpoints. Persisted freezes are always user freezes
/// (system/payjoin locks are derived live, never stored), so unfreezing is safe
/// by construction. Maps any failure to [CoinsUnfreezeFailure].
class UnfreezeUtxosUsecase {
  UnfreezeUtxosUsecase({required this._walletUtxoRepository});

  final WalletUtxoRepository _walletUtxoRepository;

  Future<Result<void, CoinsFailure>> execute({
    required String walletId,
    required List<Outpoint> outpoints,
  }) async {
    try {
      await _walletUtxoRepository.unfreezeUtxos(
        walletId: walletId,
        outpoints: outpoints,
      );
      return const Ok(null);
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to unfreeze wallet coins',
        error: error,
        trace: stackTrace,
      );
      return Err(CoinsUnfreezeFailure(error.toString()));
    }
  }
}
