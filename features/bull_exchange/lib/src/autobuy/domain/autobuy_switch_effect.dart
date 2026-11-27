import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';

import 'autobuy_state.dart';

@immutable
sealed class AutoBuySwitchEffect {
  const AutoBuySwitchEffect();
}

final class SwitchConfirmEffect extends AutoBuySwitchEffect {
  final ServerConfirmEffect<AutoBuyTarget> effect;

  const SwitchConfirmEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is SwitchConfirmEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(SwitchConfirmEffect, effect);
}

/// Tell the dashboard the account changed, so it reads it again.
final class SwitchAccountChanged extends AutoBuySwitchEffect {
  const SwitchAccountChanged();

  @override
  bool operator ==(Object other) => other is SwitchAccountChanged;

  @override
  int get hashCode => (SwitchAccountChanged).hashCode;
}
