import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'buy_error.freezed.dart';

@freezed
sealed class BuyError with _$BuyError {
  const factory BuyError.unauthenticated() = UnauthenticatedBuyError;

  /// [minAmount] is denominated in [currency], which the api picks and can be
  /// either a fiat currency or BTC/LBTC.
  const factory BuyError.belowMinAmount({
    required double minAmount,
    required String currency,
  }) = BelowMinAmountBuyError;
  const factory BuyError.aboveMaxAmount({
    required double maxAmount,
    required String currency,
  }) = AboveMaxAmountBuyError;
  const factory BuyError.insufficientFunds() = InsufficientFundsBuyError;
  const factory BuyError.orderNotFound() = OrderNotFoundBuyError;
  const factory BuyError.orderAlreadyConfirmed() =
      OrderAlreadyConfirmedBuyError;
  const factory BuyError.payjoinSettingUpdateFailed() =
      PayjoinSettingUpdateFailedBuyError;
  const factory BuyError.unexpected({required String message}) =
      UnexpectedBuyError;

  const BuyError._();

  /// Returns the localized error message.
  String toTranslated(BuildContext context) => when(
    unauthenticated: () => context.loc.buyUnauthenticatedError,
    belowMinAmount: (_, _) => context.loc.buyBelowMinAmountError,
    aboveMaxAmount: (_, _) => context.loc.buyAboveMaxAmountError,
    insufficientFunds: () => context.loc.buyInsufficientFundsError,
    orderNotFound: () => context.loc.buyOrderNotFoundError,
    orderAlreadyConfirmed: () => context.loc.buyOrderAlreadyConfirmedError,
    payjoinSettingUpdateFailed: () =>
        context.loc.payjoinTradingSettingUpdateError,
    // The raw message is logged by the bloc; it is never fit to show to a user.
    unexpected: (_) => context.loc.buyUnexpectedError,
  );
}
