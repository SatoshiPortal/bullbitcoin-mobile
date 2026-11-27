import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';

import 'limit_order_event.dart';
import 'limit_order_state.dart';

@immutable
sealed class LimitFlowEffect {
  const LimitFlowEffect();
}

final class LimitLoadContext extends LimitFlowEffect {
  final int attempt;

  const LimitLoadContext(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is LimitLoadContext && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(LimitLoadContext, attempt);
}

/// Read the rate of [market]; answer [LimitTargetRateArrived] for [attempt].
final class LimitFetchTargetRate extends LimitFlowEffect {
  final Market market;
  final int attempt;

  const LimitFetchTargetRate(this.market, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is LimitFetchTargetRate &&
      other.market == market &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(LimitFetchTargetRate, market, attempt);
}

final class LimitDestinationEffect extends LimitFlowEffect {
  final PickEffect<DestinationOption> effect;

  const LimitDestinationEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is LimitDestinationEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(LimitDestinationEffect, effect);
}

/// Read the account again after the KYC detour; answer [LimitDetourLoaded].
final class LimitReloadForDetour extends LimitFlowEffect {
  const LimitReloadForDetour();

  @override
  bool operator ==(Object other) => other is LimitReloadForDetour;

  @override
  int get hashCode => (LimitReloadForDetour).hashCode;
}

/// Read the rate of [market]; answer [LimitReviewRateArrived] for [attempt].
final class LimitFetchReviewRate extends LimitFlowEffect {
  final Market market;
  final int attempt;

  const LimitFetchReviewRate(this.market, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is LimitFetchReviewRate &&
      other.market == market &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(LimitFetchReviewRate, market, attempt);
}

final class LimitConfirmEffect extends LimitFlowEffect {
  final ServerConfirmEffect<LimitOrderRequest> effect;

  const LimitConfirmEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is LimitConfirmEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(LimitConfirmEffect, effect);
}
