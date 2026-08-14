import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sell_error.freezed.dart';

@freezed
sealed class SellError with _$SellError {
  const factory SellError.unauthenticated() = UnauthenticatedSellError;

  /// [minAmount] is denominated in [currency], which the api picks and can be
  /// either a fiat currency or BTC/LBTC.
  const factory SellError.belowMinAmount({
    required double minAmount,
    required String currency,
  }) = BelowMinAmountSellError;
  const factory SellError.aboveMaxAmount({
    required double maxAmount,
    required String currency,
  }) = AboveMaxAmountSellError;
  const factory SellError.orderNotFound() = OrderNotFoundSellError;
  const factory SellError.orderAlreadyConfirmed() =
      OrderAlreadyConfirmedSellError;

  /// A price-lock refresh came back with a different deposit address than
  /// the order was created with. That must never happen in correct backend
  /// operation, so the refreshed order is refused rather than paid.
  const factory SellError.depositAddressChanged() =
      DepositAddressChangedSellError;
  const factory SellError.unexpected({required String message}) =
      UnexpectedSellError;
  const factory SellError.insufficientBalance({
    required int requiredAmountSat,
  }) = InsufficientBalanceSellError;

  const SellError._();

  /// Returns the localized error message.
  String toTranslated(BuildContext context) => when(
    unauthenticated: () => context.loc.sellUnauthenticatedError,
    belowMinAmount: (_, _) => context.loc.sellBelowMinAmountError,
    aboveMaxAmount: (_, _) => context.loc.sellAboveMaxAmountError,
    orderNotFound: () => context.loc.sellOrderNotFoundError,
    orderAlreadyConfirmed: () => context.loc.sellOrderAlreadyConfirmedError,
    depositAddressChanged: () => context.loc.sellDepositAddressChangedError,
    unexpected: (message) => message,
    insufficientBalance: (_) => context.loc.sellInsufficientBalanceError,
  );
}
