import 'package:bb_mobile/features/coins/public/coins_facade.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Pay's boundary onto the shared UTXO use-case, which still throws.
class LoadPayWalletUtxosUsecase {
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;

  const LoadPayWalletUtxosUsecase({required this._getWalletUtxosUsecase});

  @useResult
  Future<Result<List<WalletUtxo>, PayFailure>> execute({
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
      return Err(PayUnexpectedFailure('Failed to load UTXOs: $e'));
    }
  }
}
