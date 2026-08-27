import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart'
    as core;
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class DeleteWalletUsecase {
  final core.DeleteWalletUsecase _deleteWallet;
  final SwapFacade _swapFacade;

  const DeleteWalletUsecase(this._deleteWallet, this._swapFacade);

  Future<void> execute({required String walletId}) async {
    switch (await _swapFacade.getPendingOrders()) {
      case Ok(:final value):
        final hasActiveOrder = value.any(
          (order) =>
              order.sourceWalletId == walletId ||
              order.destinationWalletId == walletId,
        );
        if (hasActiveOrder) {
          throw const WalletError.cannotDeleteWalletWithOngoingSwaps();
        }
      case Err():
        throw const WalletError.unexpected(
          'Could not verify active swap orders',
        );
    }
    await _deleteWallet.execute(walletId: walletId);
  }
}
