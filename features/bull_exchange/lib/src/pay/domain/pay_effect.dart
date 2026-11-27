import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';

import 'pay_state.dart';

@immutable
sealed class PayFlowEffect {
  const PayFlowEffect();

  Object get _value;

  @override
  bool operator ==(Object other) =>
      other is PayFlowEffect &&
      other.runtimeType == runtimeType &&
      other._value == _value;

  @override
  int get hashCode => Object.hash(runtimeType, _value);

  @override
  String toString() => '$runtimeType($_value)';
}

final class PayLoadContext extends PayFlowEffect {
  final int attempt;

  const PayLoadContext(this.attempt);

  @override
  Object get _value => attempt;
}

final class PayReloadForDetour extends PayFlowEffect {
  const PayReloadForDetour();

  @override
  Object get _value => 0;
}

final class PayFetchRate extends PayFlowEffect {
  final Market market;

  const PayFetchRate(this.market);

  @override
  Object get _value => market;
}

final class PayRequirementsEffect extends PayFlowEffect {
  final RequirementsEffect effect;

  const PayRequirementsEffect(this.effect);

  @override
  Object get _value => effect;
}

final class PayOrderEffect extends PayFlowEffect {
  final OrderStepEffect<PayRequest> effect;

  const PayOrderEffect(this.effect);

  @override
  Object get _value => effect;
}

final class PaySpendEffect extends PayFlowEffect {
  final SpendOptionsEffect effect;

  const PaySpendEffect(this.effect);

  @override
  Object get _value => effect;
}

final class PayPayinEffect extends PayFlowEffect {
  final PayinEffect<PayinSpend> effect;

  const PayPayinEffect(this.effect);

  @override
  Object get _value => effect;
}

final class PayReceiptEffect extends PayFlowEffect {
  final OutcomeWatchEffect effect;

  const PayReceiptEffect(this.effect);

  @override
  Object get _value => effect;
}
