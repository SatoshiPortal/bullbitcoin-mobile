import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/catalog/market.dart';
import '../domain/exchange_failure.dart';
import 'amount_entry_state.dart';

@immutable
sealed class AmountEntryEvent {
  const AmountEntryEvent();
}

final class AmountTyped extends AmountEntryEvent {
  final String text;

  const AmountTyped(this.text);
}

final class AmountUnitToggled extends AmountEntryEvent {
  const AmountUnitToggled();
}

final class AmountDescriptionTyped extends AmountEntryEvent {
  final String text;

  const AmountDescriptionTyped(this.text);
}

final class AmountMarketChosen extends AmountEntryEvent {
  final Market market;

  const AmountMarketChosen(this.market);
}

/// The rate read for [market] answered [read] (fiat per bitcoin).
final class AmountRateArrived extends AmountEntryEvent {
  final Market market;
  final Result<double, ExchangeReadFailure> read;

  const AmountRateArrived(this.market, this.read);
}

final class AmountRateRetryPressed extends AmountEntryEvent {
  const AmountRateRetryPressed();
}

final class AmountContinuePressed extends AmountEntryEvent {
  const AmountContinuePressed();
}

/// Back from the KYC or funding detour, with the context read again.
final class AmountDetourReturned extends AmountEntryEvent {
  final AmountContext context;

  const AmountDetourReturned(this.context);
}

/// Back from the next step to this one.
final class AmountEditRequested extends AmountEntryEvent {
  const AmountEditRequested();
}

/// The exchange refused an order for the entered amount: it broke [limit].
/// The step goes back to editing the same draft, knowing the limit.
final class AmountLimitRefused extends AmountEntryEvent {
  final ExchangeOrderLimit limit;

  const AmountLimitRefused(this.limit);
}
