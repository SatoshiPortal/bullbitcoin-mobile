import 'package:primitives/primitives.dart';
import 'package:transactions/transactions.dart';
import 'package:labels/labels.dart';
import 'package:swaps/order_swaps.dart';

class ApplyCompletedOrderSwapLabelsUsecase {
  final OrderSwaps _orders;
  final Transactions _walletTransactions;
  final Labels _labelsFacade;
  final DateTime Function() _now;

  ApplyCompletedOrderSwapLabelsUsecase(
    this._orders,
    this._walletTransactions,
    this._labelsFacade, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  Future<Result<int, SwapFailure>> execute() async {
    final orders = <OrderSwapRecord>[];
    for (final purpose in [
      OrderSwapPurpose.sendLightning,
      OrderSwapPurpose.receiveLightning,
    ]) {
      switch (await _orders.getOrdersAwaitingLabels(purpose: purpose)) {
        case Ok(:final value):
          orders.addAll(value);
        case Err(:final failure):
          return Err(failure);
      }
    }

    var appliedCount = 0;
    for (final order in orders) {
      final isIncoming = order.sourceWalletId == null;
      final walletId = order.sourceWalletId ?? order.destinationWalletId;
      final transactionId = isIncoming
          ? switch (order.outNetwork) {
              OrderSwapNetwork.bitcoin => order.order?.bitcoinTransactionId,
              OrderSwapNetwork.liquid => order.order?.liquidTransactionId,
              OrderSwapNetwork.lightning => null,
            }
          : order.localPayinTransactionId ??
                switch (order.inNetwork) {
                  OrderSwapNetwork.bitcoin => order.order?.bitcoinTransactionId,
                  OrderSwapNetwork.liquid => order.order?.liquidTransactionId,
                  OrderSwapNetwork.lightning => null,
                };
      if (walletId == null || transactionId == null) continue;

      final history = await _walletTransactions.getWalletTransaction(
        transactionId,
        walletId: walletId,
      );
      switch (history) {
        case Ok(:final value) when value?.isConfirmed == true:
          break;
        case Ok():
          continue;
        case Err(:final failure):
          return Err(SwapUnexpectedFailure(failure.runtimeType.toString()));
      }

      final labels = [
        LabelSystem.swaps.label,
        if (order.note?.trim().isNotEmpty == true) order.note!.trim(),
      ];
      for (final label in labels) {
        switch (await _labelsFacade.store(
          NewLabel.tx(
            transactionId: transactionId,
            label: label,
            origin: walletId,
          ),
        )) {
          case Ok():
            break;
          case Err(:final failure):
            return Err(SwapStorageFailure(failure.runtimeType.toString()));
        }
      }

      switch (await _orders.markLabelsApplied(
        localId: order.localId,
        appliedAt: _now().toUtc(),
      )) {
        case Ok():
          appliedCount++;
        case Err(:final failure):
          return Err(failure);
      }
    }
    return Ok(appliedCount);
  }
}
