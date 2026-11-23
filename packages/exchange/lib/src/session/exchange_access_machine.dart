import 'package:meta/meta.dart';

import '../domain/exchange_access.dart';
import '../domain/exchange_environment.dart';

/// What the access lifecycle learned or did. The lifecycle reads storage and
/// runs the effects; [transitionAccess] alone decides the next state.
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

/// Whether a completed web sign-in may store its key in [access].
bool accessAcceptsKey(ExchangeAccess access) => switch (access) {
  ExchangeAccessSignedOut() ||
  ExchangeAccessSignedIn() ||
  ExchangeAccessExpiring() ||
  ExchangeAccessCredentialUnreadable() => true,
  ExchangeAccessResolving() ||
  ExchangeAccessUnreadable() ||
  ExchangeAccessDisabled() ||
  ExchangeAccessSignOutIncomplete() => false,
};

/// The access table. A sign-out in progress is left only by its completion;
/// a session ends only through sign-out, expiry or a read that finds another
/// answer; a key found again for the current session's environment keeps
/// that session (no new epoch).
ExchangeAccess transitionAccess(
  ExchangeAccess state,
  ExchangeAccessEvent event,
) => switch ((state, event)) {
  // A sign-out in progress ignores every read; only its end leaves it.
  (
    ExchangeAccessSignOutIncomplete(),
    AccessChoiceUnreadable() ||
        AccessFoundDisabled() ||
        AccessFoundSignOutPending() ||
        AccessFoundSignedOut() ||
        AccessFoundKey() ||
        AccessKeyUnreadable() ||
        AccessKeyStored() ||
        AccessSignOutStarted() ||
        AccessSignOutFailed() ||
        AccessSessionRejected() ||
        AccessExpiryCompleted() ||
        AccessExpiryFailed(),
  ) =>
    state,
  (ExchangeAccessSignOutIncomplete(), AccessSignOutCompleted()) =>
    const ExchangeAccessDisabled(),

  // Reads decide the state outside a sign-out.
  (
    ExchangeAccessResolving() ||
        ExchangeAccessUnreadable() ||
        ExchangeAccessDisabled() ||
        ExchangeAccessSignedOut() ||
        ExchangeAccessSignedIn() ||
        ExchangeAccessExpiring() ||
        ExchangeAccessCredentialUnreadable(),
    AccessChoiceUnreadable(),
  ) =>
    const ExchangeAccessUnreadable(),
  (
    ExchangeAccessResolving() ||
        ExchangeAccessUnreadable() ||
        ExchangeAccessDisabled() ||
        ExchangeAccessSignedOut() ||
        ExchangeAccessSignedIn() ||
        ExchangeAccessExpiring() ||
        ExchangeAccessCredentialUnreadable(),
    AccessFoundDisabled(),
  ) =>
    const ExchangeAccessDisabled(),
  (
    ExchangeAccessResolving() ||
        ExchangeAccessUnreadable() ||
        ExchangeAccessDisabled() ||
        ExchangeAccessSignedOut() ||
        ExchangeAccessSignedIn() ||
        ExchangeAccessExpiring() ||
        ExchangeAccessCredentialUnreadable(),
    AccessFoundSignOutPending() || AccessSignOutStarted(),
  ) =>
    const ExchangeAccessSignOutIncomplete(),
  (
    ExchangeAccessResolving() ||
        ExchangeAccessUnreadable() ||
        ExchangeAccessDisabled() ||
        ExchangeAccessSignedOut() ||
        ExchangeAccessSignedIn() ||
        ExchangeAccessExpiring() ||
        ExchangeAccessCredentialUnreadable(),
    AccessFoundSignedOut(:final environment),
  ) =>
    ExchangeAccessSignedOut(environment),
  (ExchangeAccessSignedIn(:final session), AccessFoundKey(:final candidate))
      when session.environment == candidate.environment =>
    state,
  (
    ExchangeAccessResolving() ||
        ExchangeAccessUnreadable() ||
        ExchangeAccessDisabled() ||
        ExchangeAccessSignedOut() ||
        ExchangeAccessSignedIn() ||
        ExchangeAccessExpiring() ||
        ExchangeAccessCredentialUnreadable(),
    AccessFoundKey(:final candidate),
  ) =>
    ExchangeAccessSignedIn(candidate),
  (
    ExchangeAccessResolving() ||
        ExchangeAccessUnreadable() ||
        ExchangeAccessDisabled() ||
        ExchangeAccessSignedOut() ||
        ExchangeAccessSignedIn() ||
        ExchangeAccessExpiring() ||
        ExchangeAccessCredentialUnreadable(),
    AccessKeyUnreadable(:final environment),
  ) =>
    ExchangeAccessCredentialUnreadable(environment),

  // A stored key starts a session only where sign-in is possible.
  (
    ExchangeAccessSignedOut() ||
        ExchangeAccessSignedIn() ||
        ExchangeAccessExpiring() ||
        ExchangeAccessCredentialUnreadable(),
    AccessKeyStored(:final session),
  ) =>
    ExchangeAccessSignedIn(session),
  (
    ExchangeAccessResolving() ||
        ExchangeAccessUnreadable() ||
        ExchangeAccessDisabled(),
    AccessKeyStored(),
  ) =>
    state,

  // A sign-out that is not running has nothing to complete or fail.
  (
    ExchangeAccessResolving() ||
        ExchangeAccessUnreadable() ||
        ExchangeAccessDisabled() ||
        ExchangeAccessSignedOut() ||
        ExchangeAccessSignedIn() ||
        ExchangeAccessExpiring() ||
        ExchangeAccessCredentialUnreadable(),
    AccessSignOutCompleted() || AccessSignOutFailed(),
  ) =>
    state,

  // Expiry belongs to the session it names.
  (ExchangeAccessSignedIn(:final session), AccessSessionRejected(:final epoch))
      when session.epoch == epoch =>
    ExchangeAccessExpiring(session),
  (ExchangeAccessExpiring(:final session), AccessExpiryCompleted(:final epoch))
      when session.epoch == epoch =>
    ExchangeAccessSignedOut(session.environment),
  (
    ExchangeAccessResolving() ||
        ExchangeAccessUnreadable() ||
        ExchangeAccessDisabled() ||
        ExchangeAccessSignedOut() ||
        ExchangeAccessSignedIn() ||
        ExchangeAccessExpiring() ||
        ExchangeAccessCredentialUnreadable(),
    AccessSessionRejected() || AccessExpiryCompleted() || AccessExpiryFailed(),
  ) =>
    state,
};
