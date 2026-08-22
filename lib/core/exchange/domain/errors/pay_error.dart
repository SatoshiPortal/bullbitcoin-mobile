import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pay_error.freezed.dart';

@freezed
sealed class PayError with _$PayError {
  const factory PayError.unauthenticated() = UnauthenticatedPayError;

  /// [minAmount] is denominated in [currency], which the api picks and can be
  /// either a fiat currency or BTC/LBTC.
  const factory PayError.belowMinAmount({
    required double minAmount,
    required String currency,
  }) = BelowMinAmountPayError;
  const factory PayError.aboveMaxAmount({
    required double maxAmount,
    required String currency,
  }) = AboveMaxAmountPayError;
  const factory PayError.insufficientBalance() = InsufficientBalancePayError;
  const factory PayError.orderNotFound() = OrderNotFoundPayError;
  const factory PayError.orderAlreadyConfirmed() =
      OrderAlreadyConfirmedPayError;

  /// A price-lock refresh came back with a different deposit address than
  /// the order was created with. That must never happen in correct backend
  /// operation, so the refreshed order is refused rather than paid.
  const factory PayError.depositAddressChanged() =
      DepositAddressChangedPayError;
  const factory PayError.payjoinSettingUpdateFailed() =
      PayjoinSettingUpdateFailedPayError;
  const factory PayError.unexpected({required String message}) =
      UnexpectedPayError;

  const PayError._();

  /// Returns the localized error message.
  String toTranslated(BuildContext context) => when(
    unauthenticated: () => context.loc.payNotAuthenticated,
    belowMinAmount: (_, _) => context.loc.payBelowMinAmount,
    aboveMaxAmount: (_, _) => context.loc.payAboveMaxAmount,
    insufficientBalance: () => context.loc.payInsufficientBalance,
    orderNotFound: () => context.loc.payOrderNotFound,
    orderAlreadyConfirmed: () => context.loc.payOrderAlreadyConfirmed,
    depositAddressChanged: () => context.loc.payDepositAddressChangedError,
    payjoinSettingUpdateFailed: () =>
        context.loc.payjoinTradingSettingUpdateError,
    unexpected: (message) => message,
  );
}
