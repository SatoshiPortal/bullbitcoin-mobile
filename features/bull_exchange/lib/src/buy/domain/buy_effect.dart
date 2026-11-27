import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';

import 'buy_event.dart';
import 'buy_state.dart';

@immutable
sealed class BuyFlowEffect {
  const BuyFlowEffect();
}

final class BuyLoadContext extends BuyFlowEffect {
  final int attempt;

  const BuyLoadContext(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is BuyLoadContext && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(BuyLoadContext, attempt);
}

/// Read the account again after a detour; answer [BuyDetourLoaded].
final class BuyReloadForDetour extends BuyFlowEffect {
  const BuyReloadForDetour();

  @override
  bool operator ==(Object other) => other is BuyReloadForDetour;

  @override
  int get hashCode => (BuyReloadForDetour).hashCode;
}

final class BuyFetchRate extends BuyFlowEffect {
  final Market market;

  const BuyFetchRate(this.market);

  @override
  bool operator ==(Object other) =>
      other is BuyFetchRate && other.market == market;

  @override
  int get hashCode => Object.hash(BuyFetchRate, market);
}

final class BuyDestinationEffect extends BuyFlowEffect {
  final PickEffect<DestinationOption> effect;

  const BuyDestinationEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is BuyDestinationEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(BuyDestinationEffect, effect);
}

final class BuyOrderEffect extends BuyFlowEffect {
  final OrderStepEffect<BuyRequest> effect;

  const BuyOrderEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is BuyOrderEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(BuyOrderEffect, effect);
}

final class BuyConfirmEffect extends BuyFlowEffect {
  final ServerConfirmEffect<BuyConfirmTarget> effect;

  const BuyConfirmEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is BuyConfirmEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(BuyConfirmEffect, effect);
}

final class BuyWatchEffect extends BuyFlowEffect {
  final OutcomeWatchEffect effect;

  const BuyWatchEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is BuyWatchEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(BuyWatchEffect, effect);
}

/// The payout of [order] completed: label the completed order and sync the
/// app wallet it went to ([walletId], null for an external address).
final class BuyPayoutSettled extends BuyFlowEffect {
  final BuyOrder order;
  final String? walletId;

  const BuyPayoutSettled(this.order, this.walletId);

  @override
  bool operator ==(Object other) =>
      other is BuyPayoutSettled &&
      other.order.orderId == order.orderId &&
      other.walletId == walletId;

  @override
  int get hashCode => Object.hash(BuyPayoutSettled, order.orderId, walletId);
}
