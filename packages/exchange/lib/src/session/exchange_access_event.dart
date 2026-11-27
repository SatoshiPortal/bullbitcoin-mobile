import 'package:meta/meta.dart';

import '../domain/exchange_access.dart';
import '../domain/exchange_environment.dart';

/// What the access lifecycle learned or did. The lifecycle reads storage and
/// runs the effects; [ExchangeAccess.next] alone decides the next state.
@immutable
sealed class ExchangeAccessEvent {
  const ExchangeAccessEvent();
}

/// The stored access choice could not be read or written.
final class AccessChoiceUnreadable extends ExchangeAccessEvent {
  const AccessChoiceUnreadable();
}

/// The stored choice says the exchange is off.
final class AccessFoundDisabled extends ExchangeAccessEvent {
  const AccessFoundDisabled();
}

/// The journal holds a sign-out that did not finish.
final class AccessFoundSignOutPending extends ExchangeAccessEvent {
  const AccessFoundSignOutPending();
}

/// Enabled, and [environment] has no key.
final class AccessFoundSignedOut extends ExchangeAccessEvent {
  final ExchangeEnvironment environment;

  const AccessFoundSignedOut(this.environment);
}

/// Enabled, and [candidate]'s environment has a key. [candidate] is the
/// session to start if none of that environment is current.
final class AccessFoundKey extends ExchangeAccessEvent {
  final ExchangeSession candidate;

  const AccessFoundKey(this.candidate);
}

/// Enabled, and the key store of [environment] could not be read.
final class AccessKeyUnreadable extends ExchangeAccessEvent {
  final ExchangeEnvironment environment;

  const AccessKeyUnreadable(this.environment);
}

/// A key from a completed web sign-in was stored for [session].
final class AccessKeyStored extends ExchangeAccessEvent {
  final ExchangeSession session;

  const AccessKeyStored(this.session);
}

final class AccessSignOutStarted extends ExchangeAccessEvent {
  const AccessSignOutStarted();
}

/// Every credential, cookie and the journal are cleared.
final class AccessSignOutCompleted extends ExchangeAccessEvent {
  const AccessSignOutCompleted();
}

/// A cleanup step failed; the sign-out stays incomplete until a retry.
final class AccessSignOutFailed extends ExchangeAccessEvent {
  const AccessSignOutFailed();
}

/// The server rejected the key of the session with [epoch].
final class AccessSessionRejected extends ExchangeAccessEvent {
  final int epoch;

  const AccessSessionRejected(this.epoch);
}

/// The rejected key of the session with [epoch] is removed.
final class AccessExpiryCompleted extends ExchangeAccessEvent {
  final int epoch;

  const AccessExpiryCompleted(this.epoch);
}

/// Removing the rejected key of the session with [epoch] failed.
final class AccessExpiryFailed extends ExchangeAccessEvent {
  final int epoch;

  const AccessExpiryFailed(this.epoch);
}
