part of 'dlc_place_order_cubit.dart';

@freezed
abstract class DlcPlaceOrderState with _$DlcPlaceOrderState {
  const factory DlcPlaceOrderState({
    @Default(DlcOptionType.call) DlcOptionType optionType,
    @Default(DlcOrderSide.buy) DlcOrderSide side,
    @Default(0) int strikePriceSat,
    @Default(0) int premiumSat,
    @Default(1) int quantity,
    @Default(0) int expiryTimestamp,
    @Default(false) bool isSubmitting,
    DlcOrder? submittedOrder,
    Exception? error,
  }) = _DlcPlaceOrderState;
  const DlcPlaceOrderState._();

  bool get isValid =>
      strikePriceSat > 0 &&
      premiumSat > 0 &&
      quantity > 0 &&
      expiryTimestamp > DateTime.now().millisecondsSinceEpoch ~/ 1000;

  bool get isSuccess => submittedOrder != null;
}
