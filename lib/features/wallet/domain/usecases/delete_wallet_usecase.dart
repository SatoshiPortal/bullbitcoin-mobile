import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart'
    as core;
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:meta/meta.dart';

/// Adds the Exchange-order check the core use case cannot make: the swap
/// feature owns pending orders, and a wallet with one in flight must not go.
class DeleteWalletUsecase {
  final core.DeleteWalletUsecase _deleteWallet;
  final SwapFacade _swapFacade;

  const DeleteWalletUsecase(this._deleteWallet, this._swapFacade);

  @useResult
  Future<Result<void, WalletFailure>> execute({
    required String walletId,
  }) async {
    switch (await _swapFacade.getPendingOrders()) {
      case Ok(:final value):
        final hasActiveOrder = value.any(
          (order) =>
              order.sourceWalletId == walletId ||
              order.destinationWalletId == walletId,
        );
        if (hasActiveOrder) {
          return const Err(WalletCannotDeleteWithOngoingSwapsFailure());
        }
      case Err(:final failure):
        // Cannot prove the wallet is safe to delete, so refuse rather than
        // risk stranding an in-flight order.
        return Err(
          WalletUnexpectedFailure(
            'pending order check: ${failure.runtimeType}',
          ),
        );
    }

    return _deleteWallet.execute(walletId: walletId);
  }
}
