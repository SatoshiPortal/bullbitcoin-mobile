import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_failure.dart';

@immutable
sealed class ConsentGateEvent {
  const ConsentGateEvent();
}

final class ConsentStartPressed extends ConsentGateEvent {
  const ConsentStartPressed();
}

final class ConsentAcceptPressed extends ConsentGateEvent {
  const ConsentAcceptPressed();
}

final class ConsentDeclinePressed extends ConsentGateEvent {
  const ConsentDeclinePressed();
}

final class ConsentSubmitted extends ConsentGateEvent {
  final int attempt;
  final Result<void, ExchangeWriteFailure> write;

  const ConsentSubmitted(this.attempt, this.write);
}

/// The re-read of [attempt]: [Ok] holds whether consent is on the
/// account.
final class ConsentVerified extends ConsentGateEvent {
  final int attempt;
  final Result<bool, ExchangeReadFailure> read;

  const ConsentVerified(this.attempt, this.read);
}

final class ConsentRetryPressed extends ConsentGateEvent {
  const ConsentRetryPressed();
}
