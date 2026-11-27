import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';

import 'sell_state.dart';

@immutable
sealed class SellFlowEffect {
  const SellFlowEffect();

  Object get _value;

  @override
  bool operator ==(Object other) =>
      other is SellFlowEffect &&
      other.runtimeType == runtimeType &&
      other._value == _value;

  @override
  int get hashCode => Object.hash(runtimeType, _value);

  @override
  String toString() => '$runtimeType($_value)';
}

final class SellLoadContext extends SellFlowEffect {
  final int attempt;

  const SellLoadContext(this.attempt);

  @override
  Object get _value => attempt;
}

/// Read the account again after the KYC detour.
final class SellReloadForDetour extends SellFlowEffect {
  const SellReloadForDetour();

  @override
  Object get _value => 0;
}

final class SellFetchRate extends SellFlowEffect {
  final Market market;

  const SellFetchRate(this.market);

  @override
  Object get _value => market;
}

final class SellRequirementsEffect extends SellFlowEffect {
  final RequirementsEffect effect;

  const SellRequirementsEffect(this.effect);

  @override
  Object get _value => effect;
}

final class SellOrderEffect extends SellFlowEffect {
  final OrderStepEffect<SellRequest> effect;

  const SellOrderEffect(this.effect);

  @override
  Object get _value => effect;
}

final class SellSpendEffect extends SellFlowEffect {
  final SpendOptionsEffect effect;

  const SellSpendEffect(this.effect);

  @override
  Object get _value => effect;
}

final class SellPayinEffect extends SellFlowEffect {
  final PayinEffect<PayinSpend> effect;

  const SellPayinEffect(this.effect);

  @override
  Object get _value => effect;
}
