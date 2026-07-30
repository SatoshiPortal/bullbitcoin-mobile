import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'withdraw_error.freezed.dart';

@freezed
sealed class WithdrawError with _$WithdrawError {
  const factory WithdrawError.unauthenticated() = UnauthenticatedWithdrawError;

  /// [minAmount] is denominated in [currency], which the api picks and can be
  /// either a fiat currency or BTC/LBTC.
  const factory WithdrawError.belowMinAmount({
    required double minAmount,
    required String currency,
  }) = BelowMinAmountWithdrawError;
  const factory WithdrawError.aboveMaxAmount({
    required double maxAmount,
    required String currency,
  }) = AboveMaxAmountWithdrawError;
  const factory WithdrawError.orderNotFound() = OrderNotFoundWithdrawError;
  const factory WithdrawError.orderAlreadyConfirmed() =
      OrderAlreadyConfirmedWithdrawError;
  const factory WithdrawError.unexpected({required String message}) =
      UnexpectedWithdrawError;

  const WithdrawError._();

  /// Returns the localized error message.
  String toTranslated(BuildContext context) => when(
    unauthenticated: () => context.loc.withdrawUnauthenticatedError,
    belowMinAmount: (_, _) => context.loc.withdrawBelowMinAmountError,
    aboveMaxAmount: (_, _) => context.loc.withdrawAboveMaxAmountError,
    orderNotFound: () => context.loc.withdrawOrderNotFoundError,
    orderAlreadyConfirmed: () => context.loc.withdrawOrderAlreadyConfirmedError,
    unexpected: (message) => message,
  );
}
