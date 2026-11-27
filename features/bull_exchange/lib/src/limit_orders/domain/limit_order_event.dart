import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'limit_order_state.dart';

typedef LimitPickEvent = PickEvent<DestinationOption, Destination>;

typedef LimitConfirmEvent = ServerConfirmEvent<LimitOrderRequest, LimitOrder>;

@immutable
sealed class LimitFlowEvent {
  const LimitFlowEvent();
}

final class LimitContextLoaded extends LimitFlowEvent {
  final int attempt;
  final Result<LimitOrderContext, ExchangeReadFailure> read;

  const LimitContextLoaded(this.attempt, this.read);
}

/// Retry of the page's failed read or write.
final class LimitRetryPressed extends LimitFlowEvent {
  const LimitRetryPressed();
}

final class LimitContinuePressed extends LimitFlowEvent {
  const LimitContinuePressed();
}

/// App bar, system Back or a page the user removed.
final class LimitBackPressed extends LimitFlowEvent {
  const LimitBackPressed();
}

/// Close (done page, session ended, Back to Exchange).
final class LimitDonePressed extends LimitFlowEvent {
  const LimitDonePressed();
}

final class LimitViewOrderPressed extends LimitFlowEvent {
  const LimitViewOrderPressed();
}

/// The signed-in session changed; null when signed out.
final class LimitSessionChanged extends LimitFlowEvent {
  final ExchangeSession? session;

  const LimitSessionChanged(this.session);
}

final class LimitCurrencyChosen extends LimitFlowEvent {
  final Market market;

  const LimitCurrencyChosen(this.market);
}

final class LimitPriceTyped extends LimitFlowEvent {
  final double price;

  const LimitPriceTyped(this.price);
}

final class LimitDiscountChanged extends LimitFlowEvent {
  final double discount;

  const LimitDiscountChanged(this.discount);
}

/// The target step's rate read of [attempt] for [market] answered [read].
final class LimitTargetRateArrived extends LimitFlowEvent {
  final Market market;
  final int attempt;
  final Result<LimitOrderRate, ExchangeReadFailure> read;

  const LimitTargetRateArrived(this.market, this.attempt, this.read);
}

final class LimitDestinationChanged extends LimitFlowEvent {
  final LimitPickEvent event;

  const LimitDestinationChanged(this.event);
}

final class LimitAmountChanged extends LimitFlowEvent {
  final AmountEntryEvent event;

  const LimitAmountChanged(this.event);
}

/// Back from the KYC web view the amount's detour opened.
final class LimitKycReturned extends LimitFlowEvent {
  const LimitKycReturned();
}

/// The account read again after the KYC detour.
final class LimitDetourLoaded extends LimitFlowEvent {
  final Result<LimitOrderContext, ExchangeReadFailure> read;

  const LimitDetourLoaded(this.read);
}

/// The review's rate read of [attempt] answered [read].
final class LimitReviewRateArrived extends LimitFlowEvent {
  final int attempt;
  final Result<LimitOrderRate, ExchangeReadFailure> read;

  const LimitReviewRateArrived(this.attempt, this.read);
}

final class LimitConfirmPressed extends LimitFlowEvent {
  const LimitConfirmPressed();
}

final class LimitConfirmChanged extends LimitFlowEvent {
  final LimitConfirmEvent event;

  const LimitConfirmChanged(this.event);
}
