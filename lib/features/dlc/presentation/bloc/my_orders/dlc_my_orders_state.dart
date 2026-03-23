part of 'dlc_my_orders_cubit.dart';

@freezed
abstract class DlcMyOrdersState with _$DlcMyOrdersState {
  const factory DlcMyOrdersState({
    @Default(false) bool isLoading,
    @Default(false) bool isCancelling,
    @Default([]) List<DlcOrder> orders,
    /// Order IDs currently being cancelled
    @Default([]) List<String> cancellingIds,
    /// The order ID currently being signed (taker accept flow).
    String? signingOrderId,
    /// Current step of the taker signing operation; null when idle.
    DlcSigningStep? signingStep,
    Exception? error,
  }) = _DlcMyOrdersState;
  const DlcMyOrdersState._();

  List<DlcOrder> get openOrders =>
      orders.where((o) => o.isOpen || o.isPendingMatchAccept).toList();

  List<DlcOrder> get matchedOrders => orders.where((o) => o.isMatched).toList();

  List<DlcOrder> get closedOrders => orders.where((o) => o.isCancelled).toList();
}
