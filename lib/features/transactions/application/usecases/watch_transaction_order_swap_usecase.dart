import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_error.dart';

class WatchTransactionOrderSwapUsecase {
  final SwapFacade _swapFacade;

  const WatchTransactionOrderSwapUsecase(this._swapFacade);

  Stream<OrderSwapRecord> execute(String localId) async* {
    await for (final result in _swapFacade.watchOrder(localId)) {
      switch (result) {
        case Ok(:final value):
          yield value;
        case Err():
          throw TransactionError('Failed to watch swap transaction');
      }
    }
  }
}
