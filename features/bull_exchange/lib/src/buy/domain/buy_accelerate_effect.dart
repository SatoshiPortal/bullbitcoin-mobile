import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';

import 'buy_accelerate_state.dart';

@immutable
sealed class AccelerateFlowEffect {
  const AccelerateFlowEffect();
}

final class AccelerateLoad extends AccelerateFlowEffect {
  final String orderId;
  final int attempt;

  const AccelerateLoad(this.orderId, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is AccelerateLoad &&
      other.orderId == orderId &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(AccelerateLoad, orderId, attempt);
}

final class AccelerateConfirmEffect extends AccelerateFlowEffect {
  final ServerConfirmEffect<AccelerateTarget> effect;

  const AccelerateConfirmEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is AccelerateConfirmEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(AccelerateConfirmEffect, effect);
}
