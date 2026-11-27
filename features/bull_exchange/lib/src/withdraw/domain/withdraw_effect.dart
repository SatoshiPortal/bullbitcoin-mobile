import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';

import 'withdraw_state.dart';

@immutable
sealed class WithdrawFlowEffect {
  const WithdrawFlowEffect();
}

final class WithdrawLoadContext extends WithdrawFlowEffect {
  final int attempt;

  const WithdrawLoadContext(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is WithdrawLoadContext && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(WithdrawLoadContext, attempt);
}

final class WithdrawFetchRate extends WithdrawFlowEffect {
  final Market market;

  const WithdrawFetchRate(this.market);

  @override
  bool operator ==(Object other) =>
      other is WithdrawFetchRate && other.market == market;

  @override
  int get hashCode => Object.hash(WithdrawFetchRate, market);
}

final class WithdrawRequirementsEffect extends WithdrawFlowEffect {
  final RequirementsEffect effect;

  const WithdrawRequirementsEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is WithdrawRequirementsEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(WithdrawRequirementsEffect, effect);
}

final class WithdrawOrderEffect extends WithdrawFlowEffect {
  final OrderStepEffect<WithdrawRequest> effect;

  const WithdrawOrderEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is WithdrawOrderEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(WithdrawOrderEffect, effect);
}

final class WithdrawConfirmEffect extends WithdrawFlowEffect {
  final ServerConfirmEffect<WithdrawConfirmTarget> effect;

  const WithdrawConfirmEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is WithdrawConfirmEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(WithdrawConfirmEffect, effect);
}
