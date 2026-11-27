import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/virtual_iban.dart';
import '../domain/exchange_failure.dart';
import 'virtual_iban_state.dart';

@immutable
sealed class VirtualIbanEvent {
  const VirtualIbanEvent();
}

final class VibanLoaded extends VirtualIbanEvent {
  final int attempt;
  final Result<VirtualIbanContext, ExchangeReadFailure> read;

  const VibanLoaded(this.attempt, this.read);
}

final class VibanCreatePressed extends VirtualIbanEvent {
  const VibanCreatePressed();
}

final class VibanCreated extends VirtualIbanEvent {
  final int attempt;
  final Result<VirtualIban, ExchangeWriteFailure> write;

  const VibanCreated(this.attempt, this.write);
}

/// The re-read after an unknown create; [Ok] of null means there is
/// none.
final class VibanVerified extends VirtualIbanEvent {
  final int attempt;
  final Result<VirtualIban?, ExchangeReadFailure> read;

  const VibanVerified(this.attempt, this.read);
}

final class VibanPolled extends VirtualIbanEvent {
  final int ticket;
  final Result<VirtualIban?, ExchangeReadFailure> read;

  const VibanPolled(this.ticket, this.read);
}

/// The server pushed `VIRTUAL_IBAN_ACTIVATED`: poll now.
final class VibanActivatedPushed extends VirtualIbanEvent {
  const VibanActivatedPushed();
}

final class VibanVisibilityChanged extends VirtualIbanEvent {
  final bool visible;

  const VibanVisibilityChanged({required this.visible});
}

final class VibanDeadlinePassed extends VirtualIbanEvent {
  final int round;

  const VibanDeadlinePassed(this.round);
}

final class VibanRetryPressed extends VirtualIbanEvent {
  const VibanRetryPressed();
}

/// Use regular SEPA instead.
final class VibanDeclinePressed extends VirtualIbanEvent {
  const VibanDeclinePressed();
}
