import 'package:freezed_annotation/freezed_annotation.dart';

part 'pay_error.freezed.dart';

@freezed
sealed class PayError with _$PayError {
  const factory PayError.unauthenticated() = UnauthenticatedPayError;
  const factory PayError.belowMinAmount({required int minAmountSat}) =
      BelowMinAmountPayError;
  const factory PayError.aboveMaxAmount({required int maxAmountSat}) =
      AboveMaxAmountPayError;
  const factory PayError.orderNotFound() = OrderNotFoundPayError;
  const factory PayError.orderAlreadyConfirmed() =
      OrderAlreadyConfirmedPayError;
  const factory PayError.unexpected({required String message}) =
      UnexpectedPayError;
}
