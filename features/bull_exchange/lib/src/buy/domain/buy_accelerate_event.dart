import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'buy_accelerate_state.dart';

typedef AccelerateConfirmEvent = ServerConfirmEvent<AccelerateTarget, BuyOrder>;

@immutable
sealed class AccelerateFlowEvent {
  const AccelerateFlowEvent();
}

final class AccelerateLoaded extends AccelerateFlowEvent {
  final int attempt;
  final Result<AccelerateQuote, ExchangeReadFailure> read;

  const AccelerateLoaded(this.attempt, this.read);
}

final class AccelerateRetryPressed extends AccelerateFlowEvent {
  const AccelerateRetryPressed();
}

final class AccelerateConfirmPressed extends AccelerateFlowEvent {
  const AccelerateConfirmPressed();
}

final class AccelerateConfirmChanged extends AccelerateFlowEvent {
  final AccelerateConfirmEvent event;

  const AccelerateConfirmChanged(this.event);
}

/// Back, or "Wait for free withdrawal".
final class AccelerateBackPressed extends AccelerateFlowEvent {
  const AccelerateBackPressed();
}

final class AccelerateDonePressed extends AccelerateFlowEvent {
  const AccelerateDonePressed();
}

final class AccelerateSessionChanged extends AccelerateFlowEvent {
  final ExchangeSession? session;

  const AccelerateSessionChanged(this.session);
}
