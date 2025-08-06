import 'package:freezed_annotation/freezed_annotation.dart';

part 'withdraw_error.freezed.dart';

@freezed
sealed class WithdrawError with _$WithdrawError {
  const factory WithdrawError.unauthenticated() = UnauthenticatedWithdrawError;
  const factory WithdrawError.belowMinAmount({required int minAmountSat}) =
      BelowMinAmountWithdrawError;
  const factory WithdrawError.aboveMaxAmount({required int maxAmountSat}) =
      AboveMaxAmountWithdrawError;
  const factory WithdrawError.orderNotFound() = OrderNotFoundWithdrawError;
  const factory WithdrawError.orderAlreadyConfirmed() =
      OrderAlreadyConfirmedWithdrawError;
  const factory WithdrawError.unexpected({required String message}) =
      UnexpectedWithdrawError;
}
