import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'pay_state.dart';

typedef PayOrderEvent = OrderStepEvent<PayRequest, Order>;

typedef PayPayinEvent = PayinEvent<PayinSpend>;

@immutable
sealed class PayFlowEvent {
  const PayFlowEvent();
}

final class PayContextLoaded extends PayFlowEvent {
  final int attempt;
  final Result<PayContext, ExchangeReadFailure> read;

  const PayContextLoaded(this.attempt, this.read);
}

final class PayRetryPressed extends PayFlowEvent {
  const PayRetryPressed();
}

final class PayRecipientPicked extends PayFlowEvent {
  final Recipient recipient;

  const PayRecipientPicked(this.recipient);
}

final class PayRequirementsChanged extends PayFlowEvent {
  final RequirementsEvent event;

  const PayRequirementsChanged(this.event);
}

final class PayAmountChanged extends PayFlowEvent {
  final AmountEntryEvent event;

  const PayAmountChanged(this.event);
}

final class PayKycReturned extends PayFlowEvent {
  const PayKycReturned();
}

final class PayDetourLoaded extends PayFlowEvent {
  final Result<PayContext, ExchangeReadFailure> read;

  const PayDetourLoaded(this.read);
}

final class PaySourcePicked extends PayFlowEvent {
  final PayinSource source;

  const PaySourcePicked(this.source);
}

final class PayOrderChanged extends PayFlowEvent {
  final PayOrderEvent event;

  const PayOrderChanged(this.event);
}

/// Confirm on a live quote, [at] the time pressed.
final class PayConfirmPressed extends PayFlowEvent {
  final DateTime at;

  const PayConfirmPressed(this.at);
}

/// A change of the review's spend options (or one of their answers).
final class PaySpendChanged extends PayFlowEvent {
  final SpendOptionsEvent event;

  const PaySpendChanged(this.event);
}

final class PayPayinChanged extends PayFlowEvent {
  final PayPayinEvent event;

  const PayPayinChanged(this.event);
}

final class PayReceiptChanged extends PayFlowEvent {
  final OutcomeWatchEvent<Order> event;

  const PayReceiptChanged(this.event);
}

final class PayBackPressed extends PayFlowEvent {
  const PayBackPressed();
}

final class PayDonePressed extends PayFlowEvent {
  const PayDonePressed();
}

final class PayVisibilityChanged extends PayFlowEvent {
  final bool visible;

  const PayVisibilityChanged({required this.visible});
}

final class PaySessionChanged extends PayFlowEvent {
  final ExchangeSession? session;

  const PaySessionChanged(this.session);
}
