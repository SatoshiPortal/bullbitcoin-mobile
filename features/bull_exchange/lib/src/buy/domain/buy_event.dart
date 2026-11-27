import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Result;

import 'buy_state.dart';

typedef BuyDestinationEvent = PickEvent<DestinationOption, Destination>;

typedef BuyOrderEvent = OrderStepEvent<BuyRequest, BuyOrder>;

typedef BuyConfirmEvent = ServerConfirmEvent<BuyConfirmTarget, BuyOrder>;

@immutable
sealed class BuyFlowEvent {
  const BuyFlowEvent();
}

final class BuyContextLoaded extends BuyFlowEvent {
  final int attempt;
  final Result<BuyContext, ExchangeReadFailure> read;

  const BuyContextLoaded(this.attempt, this.read);
}

/// Retry of whatever failed on screen: the load, the create, the quote, the
/// confirm's re-read or the payout watch.
final class BuyRetryPressed extends BuyFlowEvent {
  const BuyRetryPressed();
}

final class BuyAmountChanged extends BuyFlowEvent {
  final AmountEntryEvent event;

  const BuyAmountChanged(this.event);
}

/// The payout wallet dropdown: an app wallet, or null for an external
/// address.
final class BuyDestinationPicked extends BuyFlowEvent {
  final DestinationOptionAppWallet? option;

  const BuyDestinationPicked(this.option);
}

/// The external address field changed.
final class BuyAddressTyped extends BuyFlowEvent {
  final String text;

  const BuyAddressTyped(this.text);
}

/// An answer of the destination pick's lookup or validation.
final class BuyDestinationChanged extends BuyFlowEvent {
  final BuyDestinationEvent event;

  const BuyDestinationChanged(this.event);
}

final class BuyPayjoinToggled extends BuyFlowEvent {
  final bool enabled;

  const BuyPayjoinToggled(this.enabled);
}

final class BuyContinuePressed extends BuyFlowEvent {
  const BuyContinuePressed();
}

/// Back from the KYC web view; the account is read again.
final class BuyKycReturned extends BuyFlowEvent {
  const BuyKycReturned();
}

/// Back from funding the account; the account is read again.
final class BuyFundingReturned extends BuyFlowEvent {
  const BuyFundingReturned();
}

/// The account read after a detour.
final class BuyDetourLoaded extends BuyFlowEvent {
  final Result<BuyContext, ExchangeReadFailure> read;

  const BuyDetourLoaded(this.read);
}

final class BuyOrderChanged extends BuyFlowEvent {
  final BuyOrderEvent event;

  const BuyOrderChanged(this.event);
}

/// Confirm on the review, at [at]: a price whose lock has lapsed by then is
/// refreshed, never confirmed.
final class BuyConfirmPressed extends BuyFlowEvent {
  final DateTime at;

  const BuyConfirmPressed(this.at);
}

final class BuyConfirmChanged extends BuyFlowEvent {
  final BuyConfirmEvent event;

  const BuyConfirmChanged(this.event);
}

final class BuyWatchChanged extends BuyFlowEvent {
  final OutcomeWatchEvent<BuyOrder> event;

  const BuyWatchChanged(this.event);
}

/// App bar, system Back or a page the user removed.
final class BuyBackPressed extends BuyFlowEvent {
  const BuyBackPressed();
}

final class BuyDonePressed extends BuyFlowEvent {
  const BuyDonePressed();
}

/// The flow's screen became visible or hidden (route, app lifecycle).
final class BuyVisibilityChanged extends BuyFlowEvent {
  final bool visible;

  const BuyVisibilityChanged({required this.visible});
}

/// The signed-in session changed; null when signed out.
final class BuySessionChanged extends BuyFlowEvent {
  final ExchangeSession? session;

  const BuySessionChanged(this.session);
}
