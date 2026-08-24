import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

class DeleteWalletPendingTransactionUsecase {
  final SendFacade _sendFacade;

  const DeleteWalletPendingTransactionUsecase(this._sendFacade);

  @useResult
  Future<Result<void, WalletFailure>> execute(
    PendingBitcoinTransaction transaction,
  ) async => (await _sendFacade.deletePending(transaction)).mapErr(
    (failure) =>
        WalletPendingTransactionDeleteFailure(failure.runtimeType.toString()),
  );
}
