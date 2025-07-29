import 'package:freezed_annotation/freezed_annotation.dart';

part 'buy_error.freezed.dart';

@freezed
sealed class BuyError with _$BuyError {
  const factory BuyError.unauthenticated() = UnauthenticatedBuyError;
  const factory BuyError.belowMinAmount({required int minAmountSat}) =
      BelowMinAmountBuyError;
  const factory BuyError.aboveMaxAmount({required int maxAmountSat}) =
      AboveMaxAmountBuyError;
  const factory BuyError.insufficientFunds() = InsufficientFundsBuyError;
  const factory BuyError.orderNotFound() = OrderNotFoundBuyError;
  const factory BuyError.orderAlreadyConfirmed() =
      OrderAlreadyConfirmedBuyError;
  const factory BuyError.unexpected({required String message}) =
      UnexpectedBuyError;
}
