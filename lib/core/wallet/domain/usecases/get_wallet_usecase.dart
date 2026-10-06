import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
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
  Future<Wallet?> execute(String walletId, {bool sync = false}) async {
    // No try: the repository returns a Result and no longer throws.
    return switch (await _wallet.getWallet(walletId, sync: sync)) {
      Ok(:final value) => value,
      // Missing stays null, exactly as before the repository returned a
      // Result.
      Err(failure: WalletNotFoundFailure()) => null,
      Err(:final failure) => throw GetWalletException(
        'getWallet failed: ${failure.runtimeType}',
      ),
    };
  }
}

class GetWalletException extends BullException {
  GetWalletException(super.message);
}
