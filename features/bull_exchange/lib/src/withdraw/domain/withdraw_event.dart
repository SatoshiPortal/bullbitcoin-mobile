import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'withdraw_state.dart';

typedef WithdrawOrderEvent = OrderStepEvent<WithdrawRequest, WithdrawOrder>;

typedef WithdrawConfirmEvent =
    ServerConfirmEvent<WithdrawConfirmTarget, WithdrawOrder>;

@immutable
sealed class WithdrawFlowEvent {
  const WithdrawFlowEvent();
}

final class WithdrawContextLoaded extends WithdrawFlowEvent {
  final int attempt;
  final Result<WithdrawContext, ExchangeReadFailure> read;

  const WithdrawContextLoaded(this.attempt, this.read);
}

/// Retry of the account load.
final class WithdrawRetryPressed extends WithdrawFlowEvent {
  const WithdrawRetryPressed();
}

final class WithdrawAmountChanged extends WithdrawFlowEvent {
  final AmountEntryEvent event;

  const WithdrawAmountChanged(this.event);
}

final class WithdrawRecipientPicked extends WithdrawFlowEvent {
  final Recipient recipient;

  const WithdrawRecipientPicked(this.recipient);
}

final class WithdrawRequirementsChanged extends WithdrawFlowEvent {
  final RequirementsEvent event;

  const WithdrawRequirementsChanged(this.event);
}

final class WithdrawOrderChanged extends WithdrawFlowEvent {
  final WithdrawOrderEvent event;

  const WithdrawOrderChanged(this.event);
}

final class WithdrawConfirmPressed extends WithdrawFlowEvent {
  const WithdrawConfirmPressed();
}

final class WithdrawConfirmChanged extends WithdrawFlowEvent {
  final WithdrawConfirmEvent event;

  const WithdrawConfirmChanged(this.event);
}

/// App bar, system Back or a page the user removed.
final class WithdrawBackPressed extends WithdrawFlowEvent {
  const WithdrawBackPressed();
}

final class WithdrawDonePressed extends WithdrawFlowEvent {
  const WithdrawDonePressed();
}

/// The flow's screen became visible or hidden (route, app lifecycle).
final class WithdrawVisibilityChanged extends WithdrawFlowEvent {
  final bool visible;

  const WithdrawVisibilityChanged({required this.visible});
}

/// The signed-in session changed; null when signed out.
final class WithdrawSessionChanged extends WithdrawFlowEvent {
  final ExchangeSession? session;

  const WithdrawSessionChanged(this.session);
}
