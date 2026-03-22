part of 'dlc_place_order_cubit.dart';

@freezed
abstract class DlcPlaceOrderState with _$DlcPlaceOrderState {
  const factory DlcPlaceOrderState({
    String? instrumentId,
    @Default(DlcOrderSide.buy) DlcOrderSide side,
    @Default(0) int price,
    @Default(1) int quantity,
    @Default(false) bool isSubmitting,
    Map<String, dynamic>? submittedOrderResponse,
    Exception? error,
  }) = _DlcPlaceOrderState;
  const DlcPlaceOrderState._();

  bool get isValid =>
      instrumentId != null &&
      instrumentId!.isNotEmpty &&
      price > 0 &&
      quantity > 0;

  bool get isSuccess => submittedOrderResponse != null;
}
