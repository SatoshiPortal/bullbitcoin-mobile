import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_order_swaps_awaiting_labels_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/mark_order_swap_labels_applied_usecase.dart';

class ApplyCompletedOrderSwapLabelsUsecase {
  final GetOrderSwapsAwaitingLabelsUsecase _getOrders;
  final MarkOrderSwapLabelsAppliedUsecase _markApplied;
  final WalletTransactionRepository _walletTransactions;
  final LabelsFacade _labelsFacade;
  final DateTime Function() _now;

  ApplyCompletedOrderSwapLabelsUsecase(
    this._getOrders,
    this._markApplied,
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
      switch (await _getOrders.execute(purpose: purpose)) {
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

      try {
        final transaction = await _walletTransactions.getWalletTransaction(
          transactionId,
          walletId: walletId,
        );
        if (transaction?.isConfirmed != true) continue;
      } catch (error) {
        return Err(SwapUnexpectedFailure(error.runtimeType.toString()));
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

      switch (await _markApplied.execute(
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
