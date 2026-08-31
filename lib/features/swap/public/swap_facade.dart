import 'package:bull_swap/bull_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/domain/usecases/create_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_order_swap_quote_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_order_swaps_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_order_swaps_awaiting_labels_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_pending_order_swaps_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/get_swap_provider_unavailable_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/mark_order_swap_broadcast_unknown_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/mark_order_swap_payin_broadcast_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/mark_order_swap_labels_applied_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/refresh_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/refresh_order_swaps_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/replace_prepared_order_swap_payin_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/save_prepared_order_swap_payin_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/watch_order_swap_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/watch_swap_provider_unavailable_usecase.dart';

export 'package:bull_swap/bull_swap.dart';
export 'package:bb_mobile/features/swap/public/order_swap_under_review_card.dart';

class SwapFacade {
  final GetOrderSwapQuoteUsecase _getQuote;
  final CreateOrderSwapUsecase _createOrder;
  final RefreshOrderSwapUsecase _refreshOrder;
  final GetOrderSwapsUsecase _getOrders;
  final GetOrderSwapUsecase _getOrder;
  final GetPendingOrderSwapsUsecase _getPendingOrders;
  final GetOrderSwapsAwaitingLabelsUsecase _getOrdersAwaitingLabels;
  final SavePreparedOrderSwapPayinUsecase _savePreparedPayin;
  final ReplacePreparedOrderSwapPayinUsecase _replacePreparedPayin;
  final MarkOrderSwapBroadcastUnknownUsecase _markBroadcastUnknown;
  final MarkOrderSwapPayinBroadcastUsecase _markPayinBroadcast;
  final MarkOrderSwapLabelsAppliedUsecase _markLabelsApplied;
  final WatchOrderSwapUsecase _watchOrder;
  final RefreshOrderSwapsUsecase _refreshOrders;
  final GetSwapProviderUnavailableUsecase _getSwapProviderUnavailable;
  final WatchSwapProviderUnavailableUsecase _watchSwapProviderUnavailable;

  SwapFacade(
    this._getQuote,
    this._createOrder,
    this._refreshOrder,
    this._getOrders,
    this._getOrder,
    this._getPendingOrders,
    this._getOrdersAwaitingLabels,
    this._savePreparedPayin,
    this._replacePreparedPayin,
    this._markBroadcastUnknown,
    this._markPayinBroadcast,
    this._markLabelsApplied,
    this._watchOrder,
    this._refreshOrders,
    this._getSwapProviderUnavailable,
    this._watchSwapProviderUnavailable,
  );

  bool get isSwapProviderUnavailable => _getSwapProviderUnavailable.execute();

  Stream<bool> watchSwapProviderUnavailable() =>
      _watchSwapProviderUnavailable.execute();

  Future<Result<OrderSwapQuote, SwapFailure>> getQuote({
    required OrderSwapEnvironment environment,
    required BigInt amountSat,
    required bool isInAmountFixed,
    required OrderSwapNetwork inNetwork,
    required OrderSwapNetwork outNetwork,
  }) => _getQuote.execute(
    environment: environment,
    amountSat: amountSat,
    isInAmountFixed: isInAmountFixed,
    inNetwork: inNetwork,
    outNetwork: outNetwork,
  );

  Future<Result<OrderSwapRecord, SwapFailure>> createOrder({
    required BigInt amountSat,
    required bool isInAmountFixed,
    required OrderSwapNetwork inNetwork,
    required OrderSwapNetwork outNetwork,
    required String destinationAddress,
    required String? fallbackAddress,
    required OrderSwapPurpose purpose,
    required OrderSwapEnvironment environment,
    String? sourceWalletId,
    String? destinationWalletId,
    String? note,
    BigInt? quotedCounterpartAmountSat,
  }) => _createOrder.execute(
    amountSat: amountSat,
    isInAmountFixed: isInAmountFixed,
    inNetwork: inNetwork,
    outNetwork: outNetwork,
    destinationAddress: destinationAddress,
    fallbackAddress: fallbackAddress,
    purpose: purpose,
    environment: environment,
    sourceWalletId: sourceWalletId,
    destinationWalletId: destinationWalletId,
    note: note,
    quotedCounterpartAmountSat: quotedCounterpartAmountSat,
  );

  Future<Result<OrderSwapRecord, SwapFailure>> refreshOrder(String localId) =>
      _refreshOrder.execute(localId);

  Future<Result<List<OrderSwapRecord>, SwapFailure>> getOrders({
    String? walletId,
  }) => _getOrders.execute(walletId: walletId);

  Future<Result<OrderSwapRecord, SwapFailure>> getOrder(String localId) =>
      _getOrder.execute(localId);

  Future<Result<List<OrderSwapRecord>, SwapFailure>> getPendingOrders() =>
      _getPendingOrders.execute();

  Future<Result<List<OrderSwapRecord>, SwapFailure>> getOrdersAwaitingLabels({
    required OrderSwapPurpose purpose,
  }) => _getOrdersAwaitingLabels.execute(purpose: purpose);

  Future<Result<OrderSwapRecord, SwapFailure>> savePreparedPayin({
    required String localId,
    required String signedTransaction,
    required bool isPsbt,
  }) => _savePreparedPayin.execute(
    localId: localId,
    signedTransaction: signedTransaction,
    isPsbt: isPsbt,
  );

  Future<Result<OrderSwapRecord, SwapFailure>> replacePreparedPayin({
    required String localId,
    required String signedTransaction,
    required bool isPsbt,
  }) => _replacePreparedPayin.execute(
    localId: localId,
    signedTransaction: signedTransaction,
    isPsbt: isPsbt,
  );

  Future<Result<OrderSwapRecord, SwapFailure>> markBroadcastUnknown(
    String localId,
  ) => _markBroadcastUnknown.execute(localId);

  Future<Result<OrderSwapRecord, SwapFailure>> markPayinBroadcast({
    required String localId,
    required String transactionId,
  }) => _markPayinBroadcast.execute(
    localId: localId,
    transactionId: transactionId,
  );

  Future<Result<OrderSwapRecord, SwapFailure>> markLabelsApplied({
    required String localId,
    required DateTime appliedAt,
  }) => _markLabelsApplied.execute(localId: localId, appliedAt: appliedAt);

  Stream<Result<OrderSwapRecord, SwapFailure>> watchOrder(String localId) =>
      _watchOrder.execute(localId);

  Future<Result<void, SwapFailure>> refreshOrders() async {
    return switch (await _refreshOrders.execute()) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }
}
