import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:flutter/material.dart';
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

  const SellError._();

  /// Returns the localized error message.
  String toTranslated(BuildContext context) => when(
    unauthenticated: () => context.loc.sellUnauthenticatedError,
    belowMinAmount: (_) => context.loc.sellBelowMinAmountError,
    aboveMaxAmount: (_) => context.loc.sellAboveMaxAmountError,
    orderNotFound: () => context.loc.sellOrderNotFoundError,
    orderAlreadyConfirmed: () => context.loc.sellOrderAlreadyConfirmedError,
    unexpected: (message) => message,
    insufficientBalance: (_) => context.loc.sellInsufficientBalanceError,
  );
}
