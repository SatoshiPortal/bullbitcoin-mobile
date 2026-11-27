import 'package:meta/meta.dart';

import '../domain/exchange_access.dart';
import 'session_gate_effect.dart';
import 'session_gate_event.dart';
import 'step_next.dart';

/// The session gate every flow starts with (composition §4.1). Its output is
/// the [ExchangeSession] of [SessionOpen]; every later step of the flow holds
/// that session, and [SessionEnded] replaces the whole flow.
@immutable
sealed class SessionGateState {
  const SessionGateState();

  SessionGateNext next(SessionGateEvent event) {
    final state = this;
    return switch ((state, event)) {
      (SessionChecking(), SessionAccessChanged(:final access)) =>
        switch (readSessionAccess(access)) {
          AccessReadingSignedIn(:final session) => StepNext(
            SessionOpen(session),
          ),
          AccessReadingSignedOut() => const StepNext(SessionSignInRequired(), [
            SessionOpenSignIn(),
          ]),
          AccessReadingPending() => StepNext.stay(state),
          AccessReadingBlocked(:final reason) => StepNext(
            SessionUnavailable(reason),
          ),
        },
      (
        SessionChecking(),
        SessionSignInFinished() ||
            SessionSignInCancelled() ||
            SessionRetryPressed() ||
            SessionServerRejected(),
      ) =>
        StepNext.stay(state),

      // A finished sign-in is also seen as the access turning signed in.
      (SessionSignInRequired(), SessionAccessChanged(:final access)) =>
        switch (readSessionAccess(access)) {
          AccessReadingSignedIn(:final session) => StepNext(
            SessionOpen(session),
          ),
          AccessReadingSignedOut() ||
          AccessReadingPending() ||
          AccessReadingBlocked() => StepNext.stay(state),
        },
      (SessionSignInRequired(), SessionSignInFinished(:final session)) =>
        StepNext(SessionOpen(session)),
      (SessionSignInRequired(), SessionSignInCancelled()) => const StepNext(
        SessionClosed(),
        [SessionCloseFlow()],
      ),
      (
        SessionSignInRequired(),
        SessionRetryPressed() || SessionServerRejected(),
      ) =>
        StepNext.stay(state),

      (SessionUnavailable(), SessionRetryPressed()) => const StepNext(
        SessionChecking(),
        [SessionReadAccess()],
      ),
      (
        SessionUnavailable(),
        SessionAccessChanged() ||
            SessionSignInFinished() ||
            SessionSignInCancelled() ||
            SessionServerRejected(),
      ) =>
        StepNext.stay(state),

      (SessionOpen(:final session), SessionAccessChanged(:final access)) =>
        switch (readSessionAccess(access)) {
          AccessReadingSignedIn(session: final current)
              when current == session =>
            StepNext.stay(state),
          AccessReadingSignedIn() ||
          AccessReadingSignedOut() ||
          AccessReadingPending() ||
          AccessReadingBlocked() => _ended,
        },
      (
        SessionOpen(:final session),
        SessionServerRejected(session: final rejected),
      )
          when rejected == session =>
        _ended,
      (
        SessionOpen(),
        SessionServerRejected() ||
            SessionSignInFinished() ||
            SessionSignInCancelled() ||
            SessionRetryPressed(),
      ) =>
        StepNext.stay(state),

      (
        SessionEnded() || SessionClosed(),
        SessionAccessChanged() ||
            SessionSignInFinished() ||
            SessionSignInCancelled() ||
            SessionRetryPressed() ||
            SessionServerRejected(),
      ) =>
        StepNext.stay(state),
    };
  }
}

/// Waiting for the access state.
final class SessionChecking extends SessionGateState {
  const SessionChecking();
}

/// Signed out: the sign-in screen is open over the flow, which resumes when
/// it finishes.
final class SessionSignInRequired extends SessionGateState {
  const SessionSignInRequired();
}

/// The exchange can't be used right now; Retry reads the access again.
final class SessionUnavailable extends SessionGateState {
  final SessionUnavailableReason reason;

  const SessionUnavailable(this.reason);

  @override
  bool operator ==(Object other) =>
      other is SessionUnavailable && other.reason == reason;

  @override
  int get hashCode => Object.hash(SessionUnavailable, reason);

  @override
  String toString() => 'SessionUnavailable(${reason.name})';
}

enum SessionUnavailableReason {
  /// The exchange is turned off on this device.
  disabled,

  /// The access choice or the key store could not be read.
  unreadable,

  /// A sign-out has not finished.
  signOutIncomplete,
}

/// The flow runs in [session].
final class SessionOpen extends SessionGateState {
  final ExchangeSession session;

  const SessionOpen(this.session);

  @override
  bool operator ==(Object other) =>
      other is SessionOpen && other.session == session;

  @override
  int get hashCode => Object.hash(SessionOpen, session);

  @override
  String toString() => 'SessionOpen($session)';
}

/// The session the flow started with ended (signed out, another session, or
/// the server rejected its key). Terminal.
final class SessionEnded extends SessionGateState {
  const SessionEnded();
}

/// The user left the sign-in without signing in. Terminal.
final class SessionClosed extends SessionGateState {
  const SessionClosed();
}

typedef SessionGateNext = StepNext<SessionGateState, SessionGateEffect>;

SessionGateNext sessionGateStart() =>
    const StepNext(SessionChecking(), [SessionReadAccess()]);

/// How the gate reads an access state.
sealed class SessionAccessReading {
  const SessionAccessReading();
}

final class AccessReadingSignedIn extends SessionAccessReading {
  final ExchangeSession session;

  const AccessReadingSignedIn(this.session);
}

final class AccessReadingSignedOut extends SessionAccessReading {
  const AccessReadingSignedOut();
}

/// The access state is about to change by itself (resolving, or an expiry
/// removing a rejected key).
final class AccessReadingPending extends SessionAccessReading {
  const AccessReadingPending();
}

final class AccessReadingBlocked extends SessionAccessReading {
  final SessionUnavailableReason reason;

  const AccessReadingBlocked(this.reason);
}

SessionAccessReading readSessionAccess(ExchangeAccess access) =>
    switch (access) {
      ExchangeAccessSignedIn(:final session) => AccessReadingSignedIn(session),
      ExchangeAccessSignedOut() => const AccessReadingSignedOut(),
      ExchangeAccessResolving() ||
      ExchangeAccessExpiring() => const AccessReadingPending(),
      ExchangeAccessDisabled() => const AccessReadingBlocked(
        SessionUnavailableReason.disabled,
      ),
      ExchangeAccessUnreadable() || ExchangeAccessCredentialUnreadable() =>
        const AccessReadingBlocked(SessionUnavailableReason.unreadable),
      ExchangeAccessSignOutIncomplete() => const AccessReadingBlocked(
        SessionUnavailableReason.signOutIncomplete,
      ),
    };

const _ended = StepNext<SessionGateState, SessionGateEffect>(SessionEnded(), [
  SessionShowEnded(),
]);
