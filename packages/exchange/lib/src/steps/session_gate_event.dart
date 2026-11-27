import 'package:meta/meta.dart';

import '../domain/exchange_access.dart';

@immutable
sealed class SessionGateEvent {
  const SessionGateEvent();
}

/// The access state, as read or as it changed.
final class SessionAccessChanged extends SessionGateEvent {
  final ExchangeAccess access;

  const SessionAccessChanged(this.access);
}

final class SessionSignInFinished extends SessionGateEvent {
  final ExchangeSession session;

  const SessionSignInFinished(this.session);
}

final class SessionSignInCancelled extends SessionGateEvent {
  const SessionSignInCancelled();
}

final class SessionRetryPressed extends SessionGateEvent {
  const SessionRetryPressed();
}

/// A call of this flow got HTTP 401 for [session]'s key.
final class SessionServerRejected extends SessionGateEvent {
  final ExchangeSession session;

  const SessionServerRejected(this.session);
}
