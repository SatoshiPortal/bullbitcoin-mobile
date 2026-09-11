import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/coins_failure.dart';

/// Thin feature wrapper over the core [GetWalletUtxosUsecase].
///
/// Returns the rich [WalletUtxo] list (already carrying `confirmations`,
/// `isFrozen`, keychain and labels) and maps any data-layer failure to the
/// feature's sealed [CoinsFailure] at this boundary.
class GetUtxosUsecase {
  GetUtxosUsecase({required this._getWalletUtxosUsecase});

  final GetWalletUtxosUsecase _getWalletUtxosUsecase;

  Future<Result<List<WalletUtxo>, CoinsFailure>> execute({
    required String walletId,
  }) async {
    try {
      return Ok(await _getWalletUtxosUsecase.execute(walletId: walletId));
    } on GetUtxosUsecaseException catch (error, stackTrace) {
      log.warning(
        'Failed to load wallet coins',
        error: error,
        trace: stackTrace,
      );
      return Err(CoinsLoadFailure(error.toString()));
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Unexpected failure while loading wallet coins',
        error: error,
        trace: stackTrace,
      );
      return Err(CoinsUnexpectedFailure(error.toString()));
    }
  }
}
