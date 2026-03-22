part of 'dlc_orderbook_cubit.dart';

@freezed
abstract class DlcOrderbookState with _$DlcOrderbookState {
  const factory DlcOrderbookState({
    @Default(false) bool isLoading,
    @Default([]) List<DlcOrder> orders,
    String? selectedInstrumentId,
    Exception? error,
  }) = _DlcOrderbookState;
  const DlcOrderbookState._();

  List<DlcOrder> get buyOrders =>
      orders.where((o) => o.side == DlcOrderSide.buy).toList();

  List<DlcOrder> get sellOrders =>
      orders.where((o) => o.side == DlcOrderSide.sell).toList();
}
