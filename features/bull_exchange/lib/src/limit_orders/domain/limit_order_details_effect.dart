import 'package:meta/meta.dart';

import 'limit_order_cancel_effect.dart';

@immutable
sealed class LimitDetailsEffect {
  const LimitDetailsEffect();
}

final class DetailsRead extends LimitDetailsEffect {
  final String orderId;
  final int attempt;

  const DetailsRead(this.orderId, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is DetailsRead &&
      other.orderId == orderId &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(DetailsRead, orderId, attempt);
}

final class DetailsCancelEffect extends LimitDetailsEffect {
  final LimitCancelEffect effect;

  const DetailsCancelEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is DetailsCancelEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(DetailsCancelEffect, effect);
}
