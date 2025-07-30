import 'package:freezed_annotation/freezed_annotation.dart';

part 'sell_error.freezed.dart';

@freezed
sealed class SellError with _$SellError {
  const factory SellError.unauthenticated() = UnauthenticatedSellError;
  const factory SellError.belowMinAmount({required int minAmountSat}) =
      BelowMinAmountSellError;
  const factory SellError.aboveMaxAmount({required int maxAmountSat}) =
      AboveMaxAmountSellError;
  const factory SellError.orderNotFound() = OrderNotFoundSellError;
  const factory SellError.orderAlreadyConfirmed() =
      OrderAlreadyConfirmedSellError;
  const factory SellError.unexpected({required String message}) =
      UnexpectedSellError;
  const factory SellError.insufficientBalance({
    required int requiredAmountSat,
  }) = InsufficientBalanceSellError;
}
