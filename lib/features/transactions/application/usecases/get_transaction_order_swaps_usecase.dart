import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_error.dart';

class GetTransactionOrderSwapsUsecase {
  final SwapFacade _swapFacade;

  const GetTransactionOrderSwapsUsecase(this._swapFacade);

  Future<List<OrderSwapRecord>> execute({String? walletId}) async {
    return switch (await _swapFacade.getOrders(walletId: walletId)) {
      Ok(:final value) => value,
      Err() => throw TransactionError('Failed to load swap transactions'),
    };
  }
}
