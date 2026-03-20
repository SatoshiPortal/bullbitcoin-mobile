part of 'dlc_orderbook_cubit.dart';

@freezed
abstract class DlcOrderbookState with _$DlcOrderbookState {
  const factory DlcOrderbookState({
    @Default(false) bool isLoading,
    @Default([]) List<DlcOrder> orders,
    DlcOptionType? activeFilter,
    Exception? error,
  }) = _DlcOrderbookState;
  const DlcOrderbookState._();

  List<DlcOrder> get callOrders =>
      orders.where((o) => o.optionType == DlcOptionType.call).toList();

  List<DlcOrder> get putOrders =>
      orders.where((o) => o.optionType == DlcOptionType.put).toList();
}
