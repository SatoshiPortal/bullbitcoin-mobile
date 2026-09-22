import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure_bridge.dart';
import 'package:bb_mobile/core/utils/result.dart';

class GetWalletUsecase {
  final WalletRepository _wallet;

  GetWalletUsecase({required WalletRepository walletRepository})
    : _wallet = walletRepository;

  /// Returns `null` when the wallet does not exist, and throws when it exists
  /// but could not be read.
  ///
  /// That distinction is load-bearing: callers treat "missing" as a modeled
  /// value — a transaction whose counterpart wallet has been deleted still
  /// renders, without the counterpart. Collapsing both into a throw turned a
  /// deleted counterpart into a full-screen error on the transaction details.
  ///
  // TODO(#1895): convert this to return a Result once
  // refactor-errors-transactions is in develop. Eleven of its sixteen call
  // sites are in transaction_details_cubit.dart, which that branch rewrites
  // wholesale (+440/-559) and where it already wraps this use case in a
  // feature-level GetTransactionWalletUsecase. Converting here would collide
  // on those exact lines and redo work already done.
  Future<Wallet?> execute(String walletId, {bool sync = false}) async {
    try {
      return switch (await _wallet.getWallet(walletId, sync: sync)) {
        Ok(:final value) => value,
        // Missing stays null, exactly as before the repository returned a
        // Result.
        Err(failure: WalletNotFoundFailure()) => null,
        Err(:final failure) => throw WalletFailureException(failure),
      };
    } catch (e) {
      throw GetWalletException('$e');
    }
  }
}

class GetWalletException extends BullException {
  GetWalletException(super.message);
}
