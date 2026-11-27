import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'sell_state.dart';

typedef SellOrderEvent = OrderStepEvent<SellRequest, Order>;

typedef SellPayinEvent = PayinEvent<PayinSpend>;

@immutable
sealed class SellFlowEvent {
  const SellFlowEvent();
}

final class SellContextLoaded extends SellFlowEvent {
  final int attempt;
  final Result<SellContext, ExchangeReadFailure> read;

  const SellContextLoaded(this.attempt, this.read);
}

final class SellRetryPressed extends SellFlowEvent {
  const SellRetryPressed();
}

final class SellAmountChanged extends SellFlowEvent {
  final AmountEntryEvent event;

  const SellAmountChanged(this.event);
}

/// Back from the KYC detour; the account is read again.
final class SellKycReturned extends SellFlowEvent {
  const SellKycReturned();
}

final class SellDetourLoaded extends SellFlowEvent {
  final Result<SellContext, ExchangeReadFailure> read;

  const SellDetourLoaded(this.read);
}

final class SellSourcePicked extends SellFlowEvent {
  final PayinSource source;

  const SellSourcePicked(this.source);
}

final class SellPayoutPicked extends SellFlowEvent {
  final SellPayoutChoice choice;

  const SellPayoutPicked(this.choice);
}

final class SellRecipientPicked extends SellFlowEvent {
  final Recipient recipient;

  const SellRecipientPicked(this.recipient);
}

final class SellRequirementsChanged extends SellFlowEvent {
  final RequirementsEvent event;

  const SellRequirementsChanged(this.event);
}

final class SellOrderChanged extends SellFlowEvent {
  final SellOrderEvent event;

  const SellOrderChanged(this.event);
}

/// Confirm on a live quote, [at] the time pressed (the payin checks the
/// order's deadline against it).
final class SellConfirmPressed extends SellFlowEvent {
  final DateTime at;

  const SellConfirmPressed(this.at);
}

/// A change of the review's spend options (or one of their answers).
final class SellSpendChanged extends SellFlowEvent {
  final SpendOptionsEvent event;

  const SellSpendChanged(this.event);
}

final class SellPayinChanged extends SellFlowEvent {
  final SellPayinEvent event;

  const SellPayinChanged(this.event);
}

final class SellBackPressed extends SellFlowEvent {
  const SellBackPressed();
}

final class SellDonePressed extends SellFlowEvent {
  const SellDonePressed();
}

final class SellVisibilityChanged extends SellFlowEvent {
  final bool visible;

  const SellVisibilityChanged({required this.visible});
}

final class SellSessionChanged extends SellFlowEvent {
  final ExchangeSession? session;

  const SellSessionChanged(this.session);
}
