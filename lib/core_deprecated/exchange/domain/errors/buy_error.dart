import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:flutter/material.dart';
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

  const BuyError._();

  /// Returns the localized error message.
  String toTranslated(BuildContext context) => when(
    unauthenticated: () => context.loc.buyUnauthenticatedError,
    belowMinAmount: (_) => context.loc.buyBelowMinAmountError,
    aboveMaxAmount: (_) => context.loc.buyAboveMaxAmountError,
    insufficientFunds: () => context.loc.buyInsufficientFundsError,
    orderNotFound: () => context.loc.buyOrderNotFoundError,
    orderAlreadyConfirmed: () => context.loc.buyOrderAlreadyConfirmedError,
    unexpected: (message) => message,
  );
}
