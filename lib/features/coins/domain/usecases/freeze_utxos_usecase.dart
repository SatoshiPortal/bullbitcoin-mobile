import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/coins/domain/coins_failure.dart';

/// Freezes the given outpoints for a wallet (writes `origin = 'user'` rows via
/// the core repository). Maps any failure to [CoinsFreezeFailure].
class FreezeUtxosUsecase {
  FreezeUtxosUsecase({required this._walletUtxoRepository});

  final WalletUtxoRepository _walletUtxoRepository;

  Future<Result<void, CoinsFailure>> execute({
    required String walletId,
    required List<Outpoint> outpoints,
  }) async {
    try {
      await _walletUtxoRepository.freezeUtxos(
        walletId: walletId,
        outpoints: outpoints,
      );
      return const Ok(null);
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to freeze wallet coins',
        error: error,
        trace: stackTrace,
      );
      return Err(CoinsFreezeFailure(error.toString()));
    }
  }
}
