import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pay_error.freezed.dart';

@freezed
sealed class PayError with _$PayError {
  const factory PayError.unauthenticated() = UnauthenticatedPayError;
  const factory PayError.belowMinAmount({required int minAmountSat}) =
      BelowMinAmountPayError;
  const factory PayError.aboveMaxAmount({required int maxAmountSat}) =
      AboveMaxAmountPayError;
  const factory PayError.insufficientBalance() = InsufficientBalancePayError;
  const factory PayError.orderNotFound() = OrderNotFoundPayError;
  const factory PayError.orderAlreadyConfirmed() =
      OrderAlreadyConfirmedPayError;
  const factory PayError.unexpected({required String message}) =
      UnexpectedPayError;

  const PayError._();

  /// Returns the localized error message.
  String toTranslated(BuildContext context) => when(
    unauthenticated: () => context.loc.payNotAuthenticated,
    belowMinAmount: (_) => context.loc.payBelowMinAmount,
    aboveMaxAmount: (_) => context.loc.payAboveMaxAmount,
    insufficientBalance: () => context.loc.payInsufficientBalance,
    orderNotFound: () => context.loc.payOrderNotFound,
    orderAlreadyConfirmed: () => context.loc.payOrderAlreadyConfirmed,
    unexpected: (message) => message,
  );
}
