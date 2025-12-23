import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
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

  const WithdrawError._();

  /// Returns the localized error message.
  String toTranslated(BuildContext context) => when(
    unauthenticated: () => context.loc.withdrawUnauthenticatedError,
    belowMinAmount: (_) => context.loc.withdrawBelowMinAmountError,
    aboveMaxAmount: (_) => context.loc.withdrawAboveMaxAmountError,
    orderNotFound: () => context.loc.withdrawOrderNotFoundError,
    orderAlreadyConfirmed: () => context.loc.withdrawOrderAlreadyConfirmedError,
    unexpected: (message) => message,
  );
}
