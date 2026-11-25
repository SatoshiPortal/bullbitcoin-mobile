import 'package:meta/meta.dart';

import 'exchange_environment.dart';

/// One signed-in session: the environment its key belongs to, an [epoch]
/// that grows with every new session of this app run, and a [sessionId]
/// that is unique across runs (the epoch starts again at each app start).
/// A session begins only when a key is stored or found; it never changes
/// while it lasts.
@immutable
final class ExchangeSession {
  final ExchangeEnvironment environment;
  final int epoch;
  final String sessionId;

  const ExchangeSession({
    required this.environment,
    required this.epoch,
    required this.sessionId,
  });

  @override
  bool operator ==(Object other) =>
      other is ExchangeSession &&
      other.environment == environment &&
      other.epoch == epoch &&
      other.sessionId == sessionId;

  @override
  int get hashCode => Object.hash(environment, epoch, sessionId);

  @override
  String toString() => 'ExchangeSession(${environment.name}, epoch $epoch)';
}

/// Where the exchange account stands on this device. Each state holds only
/// what is known in it.
sealed class ExchangeAccess {
  const ExchangeAccess();
}

/// The stored choice and credential have not been read yet.
final class ExchangeAccessResolving extends ExchangeAccess {
  const ExchangeAccessResolving();
}

/// The stored access choice could not be read or written.
final class ExchangeAccessUnreadable extends ExchangeAccess {
  const ExchangeAccessUnreadable();
}

/// The user turned the exchange off (or never turned it on).
final class ExchangeAccessDisabled extends ExchangeAccess {
  const ExchangeAccessDisabled();
}

/// A sign-out started and has not removed every credential yet.
final class ExchangeAccessSignOutIncomplete extends ExchangeAccess {
  const ExchangeAccessSignOutIncomplete();
}

/// Enabled, with no key for [environment].
@immutable
final class ExchangeAccessSignedOut extends ExchangeAccess {
  final ExchangeEnvironment environment;

  const ExchangeAccessSignedOut(this.environment);

  @override
  bool operator ==(Object other) =>
      other is ExchangeAccessSignedOut && other.environment == environment;

  @override
  int get hashCode => Object.hash(ExchangeAccessSignedOut, environment);
}

/// Enabled, with a stored key: [session] is current.
@immutable
final class ExchangeAccessSignedIn extends ExchangeAccess {
  final ExchangeSession session;

  const ExchangeAccessSignedIn(this.session);

  @override
  bool operator ==(Object other) =>
      other is ExchangeAccessSignedIn && other.session == session;

  @override
  int get hashCode => Object.hash(ExchangeAccessSignedIn, session);
}

/// The server rejected [session]'s key; its credential is being removed.
@immutable
final class ExchangeAccessExpiring extends ExchangeAccess {
  final ExchangeSession session;

  const ExchangeAccessExpiring(this.session);

  @override
  bool operator ==(Object other) =>
      other is ExchangeAccessExpiring && other.session == session;

  @override
  int get hashCode => Object.hash(ExchangeAccessExpiring, session);
}

/// Enabled, but the key store of [environment] could not be read. The
/// stored key is kept: a read failure never signs out.
@immutable
final class ExchangeAccessCredentialUnreadable extends ExchangeAccess {
  final ExchangeEnvironment environment;

  const ExchangeAccessCredentialUnreadable(this.environment);

  @override
  bool operator ==(Object other) =>
      other is ExchangeAccessCredentialUnreadable &&
      other.environment == environment;

  @override
  int get hashCode =>
      Object.hash(ExchangeAccessCredentialUnreadable, environment);
}

extension ExchangeAccessSessionX on ExchangeAccess {
  /// The current session, only while signed in.
  ExchangeSession? get signedInSession => switch (this) {
    ExchangeAccessSignedIn(:final session) => session,
    ExchangeAccessResolving() ||
    ExchangeAccessUnreadable() ||
    ExchangeAccessDisabled() ||
    ExchangeAccessSignOutIncomplete() ||
    ExchangeAccessSignedOut() ||
    ExchangeAccessExpiring() ||
    ExchangeAccessCredentialUnreadable() => null,
  };

  bool get isSignedIn => signedInSession != null;

  /// The exchange is turned on, whatever the credential says.
  bool get isEnabled => switch (this) {
    ExchangeAccessSignedOut() ||
    ExchangeAccessSignedIn() ||
    ExchangeAccessExpiring() ||
    ExchangeAccessCredentialUnreadable() => true,
    ExchangeAccessResolving() ||
    ExchangeAccessUnreadable() ||
    ExchangeAccessDisabled() ||
    ExchangeAccessSignOutIncomplete() => false,
  };
}
