import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_failure.dart';
import '../recipients/domain/entities/sepa_virtual_payee_status.dart';

@immutable
sealed class VirtualPayeeEvent {
  const VirtualPayeeEvent();
}

/// [ExchangeMissingFailure]: the user has no SEPA recipient with this id.
final class PayeeLoaded extends VirtualPayeeEvent {
  final int attempt;
  final Result<SepaVirtualPayeeStatus, ExchangeReadFailure> read;

  const PayeeLoaded(this.attempt, this.read);
}

final class PayeeActivated extends VirtualPayeeEvent {
  final int attempt;
  final Result<SepaVirtualPayeeStatus, ExchangeWriteFailure> write;

  const PayeeActivated(this.attempt, this.write);
}

final class PayeePolled extends VirtualPayeeEvent {
  final int ticket;
  final Result<SepaVirtualPayeeStatus, ExchangeReadFailure> read;

  const PayeePolled(this.ticket, this.read);
}

final class PayeeVisibilityChanged extends VirtualPayeeEvent {
  final bool visible;

  const PayeeVisibilityChanged({required this.visible});
}

final class PayeeDeadlinePassed extends VirtualPayeeEvent {
  final int round;

  const PayeeDeadlinePassed(this.round);
}

final class PayeeRetryPressed extends VirtualPayeeEvent {
  const PayeeRetryPressed();
}

/// Use regular SEPA instead.
final class PayeeDeclinePressed extends VirtualPayeeEvent {
  const PayeeDeclinePressed();
}
