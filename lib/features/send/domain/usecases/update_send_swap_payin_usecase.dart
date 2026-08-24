import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/swap_failure_to_send_failure.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';

enum SendSwapPayinUpdate {
  prepared,
  replaced,
  broadcastStarted,
  broadcastSucceeded,
}

class UpdateSendSwapPayinUsecase {
  final SwapFacade _swapFacade;

  const UpdateSendSwapPayinUsecase(this._swapFacade);

  Future<Result<OrderSwapRecord, SendFailure>> execute({
    required String localId,
    required SendSwapPayinUpdate update,
    String? signedTransaction,
    bool? isPsbt,
    String? transactionId,
  }) async {
    final Result<OrderSwapRecord, SwapFailure> result;
    switch (update) {
      case SendSwapPayinUpdate.prepared:
        if (signedTransaction == null || isPsbt == null) {
          return const Err(
            SendTransactionBuildFailure('Signed transaction is required'),
          );
        }
        result = await _swapFacade.savePreparedPayin(
          localId: localId,
          signedTransaction: signedTransaction,
          isPsbt: isPsbt,
        );
      case SendSwapPayinUpdate.replaced:
        if (signedTransaction == null || isPsbt == null) {
          return const Err(
            SendTransactionBuildFailure('Signed transaction is required'),
          );
        }
        result = await _swapFacade.replacePreparedPayin(
          localId: localId,
          signedTransaction: signedTransaction,
          isPsbt: isPsbt,
        );
      case SendSwapPayinUpdate.broadcastStarted:
        result = await _swapFacade.markBroadcastUnknown(localId);
      case SendSwapPayinUpdate.broadcastSucceeded:
        if (transactionId == null) {
          return const Err(
            SendTransactionConfirmationFailure(
              logMessage: 'Transaction id is required',
            ),
          );
        }
        result = await _swapFacade.markPayinBroadcast(
          localId: localId,
          transactionId: transactionId,
        );
    }
    return result.mapErr((failure) {
      if (update == SendSwapPayinUpdate.prepared ||
          update == SendSwapPayinUpdate.replaced) {
        return mapSwapFailureToSendFailure(failure);
      }
      return SendTransactionConfirmationFailure(
        isBroadcastFailure: update == SendSwapPayinUpdate.broadcastStarted,
        logMessage: failure.logMessage,
      );
    });
  }
}
