import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Reads the wallet a transaction belongs to.
///
/// [GetWalletUsecase] is a shared core use-case that still throws, so this —
/// the first layer the transactions feature owns — is the boundary that
/// catches it and turns it into a [TransactionFailure] value.
class GetTransactionWalletUsecase {
  final GetWalletUsecase _getWalletUsecase;

  const GetTransactionWalletUsecase(this._getWalletUsecase);

  @useResult
  Future<Result<Wallet?, TransactionFailure>> execute(
    String walletId, {
    bool sync = false,
  }) async {
    try {
      return Ok(await _getWalletUsecase.execute(walletId, sync: sync));
    } catch (e, st) {
      log.severe(
        message: 'Failed to load the wallet of a transaction',
        error: e,
        trace: st,
      );
      return Err(
        TransactionUnexpectedFailure('getWallet failed: ${e.runtimeType}'),
      );
    }
  }
}
