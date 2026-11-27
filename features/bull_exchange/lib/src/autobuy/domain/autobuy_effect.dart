import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';

import 'autobuy_event.dart';
import 'autobuy_state.dart';

@immutable
sealed class AutoBuyFlowEffect {
  const AutoBuyFlowEffect();
}

final class AutoBuyLoadContext extends AutoBuyFlowEffect {
  final int attempt;

  const AutoBuyLoadContext(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is AutoBuyLoadContext && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(AutoBuyLoadContext, attempt);
}

/// Read the account again after KYC; answer [AutoBuyKycReloaded].
final class AutoBuyReloadForKyc extends AutoBuyFlowEffect {
  const AutoBuyReloadForKyc();

  @override
  bool operator ==(Object other) => other is AutoBuyReloadForKyc;

  @override
  int get hashCode => (AutoBuyReloadForKyc).hashCode;
}

final class AutoBuyConfirmEffect extends AutoBuyFlowEffect {
  final ServerConfirmEffect<AutoBuyTarget> effect;

  const AutoBuyConfirmEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is AutoBuyConfirmEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(AutoBuyConfirmEffect, effect);
}
