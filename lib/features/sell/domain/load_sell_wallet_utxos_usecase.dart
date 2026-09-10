import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Sell's boundary onto the shared UTXO use-case, which still throws.
class LoadSellWalletUtxosUsecase {
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;

  const LoadSellWalletUtxosUsecase({required this._getWalletUtxosUsecase});

  @useResult
  Future<Result<List<WalletUtxo>, SellFailure>> execute({
    required String walletId,
  }) async {
    try {
      return Ok(await _getWalletUtxosUsecase.execute(walletId: walletId));
    } catch (e, st) {
      log.severe(
        message: 'Failed to load the wallet utxos for coin control',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('Failed to load UTXOs: $e'));
    }
  }
}
