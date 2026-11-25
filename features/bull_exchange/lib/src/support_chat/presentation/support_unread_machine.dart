import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';

/// Why the unread count could not be read. Never shown as zero.
enum UnreadProblem { missing, unreachable, malformed, sessionRejected }

/// How many support messages the signed-in user has not read. Every
/// signed-in state names its session and the [attempt] whose answer it
/// waits for, so an answer for another session or an older attempt is a
/// stay.
@immutable
sealed class SupportUnreadState {
  const SupportUnreadState();
}

final class UnreadSignedOut extends SupportUnreadState {
  const UnreadSignedOut();

  @override
  bool operator ==(Object other) => other is UnreadSignedOut;

  @override
  int get hashCode => (UnreadSignedOut).hashCode;
}

/// Signed-in states.
sealed class UnreadSession extends SupportUnreadState {
  final ExchangeSession session;
  final int attempt;

  const UnreadSession(this.session, this.attempt);
}

/// The first read of [session]'s count; nothing is known yet.
final class UnreadReading extends UnreadSession {
  const UnreadReading(super.session, super.attempt);

  @override
  bool operator ==(Object other) =>
      other is UnreadReading &&
      other.session == session &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(UnreadReading, session, attempt);
}

/// The count was never read: [problem], not zero.
final class UnreadUnavailable extends UnreadSession {
  final UnreadProblem problem;

  const UnreadUnavailable(super.session, super.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is UnreadUnavailable &&
      other.session == session &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(UnreadUnavailable, session, attempt, problem);
}

final class UnreadKnown extends UnreadSession {
  final int count;

  const UnreadKnown(super.session, super.attempt, this.count);

  @override
  bool operator ==(Object other) =>
      other is UnreadKnown &&
      other.session == session &&
      other.attempt == attempt &&
      other.count == count;

  @override
  int get hashCode => Object.hash(UnreadKnown, session, attempt, count);
}

/// [count] is shown while it is read again.
final class UnreadRefreshing extends UnreadSession {
  final int count;

  const UnreadRefreshing(super.session, super.attempt, this.count);

  @override
  bool operator ==(Object other) =>
      other is UnreadRefreshing &&
      other.session == session &&
      other.attempt == attempt &&
      other.count == count;

  @override
  int get hashCode => Object.hash(UnreadRefreshing, session, attempt, count);
}

/// The last re-read failed with [problem]; [count] is the last one read.
final class UnreadStale extends UnreadSession {
  final int count;
  final UnreadProblem problem;

  const UnreadStale(super.session, super.attempt, this.count, this.problem);

  @override
  bool operator ==(Object other) =>
      other is UnreadStale &&
      other.session == session &&
      other.attempt == attempt &&
      other.count == count &&
      other.problem == problem;

  @override
  int get hashCode =>
      Object.hash(UnreadStale, session, attempt, count, problem);
}

/// The chat showed the newest messages: they are being marked read, and
/// the badge is clear meanwhile.
final class UnreadMarking extends UnreadSession {
  const UnreadMarking(super.session, super.attempt);

  @override
  bool operator ==(Object other) =>
      other is UnreadMarking &&
      other.session == session &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(UnreadMarking, session, attempt);
}

@immutable
sealed class SupportUnreadEvent {
  const SupportUnreadEvent();
}

final class UnreadAccessChanged extends SupportUnreadEvent {
  final ExchangeAccess access;

  const UnreadAccessChanged(this.access);
}

/// A new support message was pushed, the app came back, or the user
/// refreshed: the count may have changed.
final class UnreadRecheckRequested extends SupportUnreadEvent {
  const UnreadRecheckRequested();
}

/// The support chat showed its newest messages to the user.
final class UnreadChatShown extends SupportUnreadEvent {
  const UnreadChatShown();
}

final class UnreadCountAnswered extends SupportUnreadEvent {
  final ExchangeSession session;
  final int attempt;
  final ExchangeRead<int> read;

  const UnreadCountAnswered(this.session, this.attempt, this.read);
}

final class UnreadMarkAnswered extends SupportUnreadEvent {
  final ExchangeSession session;
  final int attempt;
  final ExchangeWrite<void> write;

  const UnreadMarkAnswered(this.session, this.attempt, this.write);
}

/// The unread count table. A new session always starts from
/// [UnreadReading]; a count read before the chat was shown can't bring the
/// badge back, because marking starts a new attempt.
SupportUnreadState transitionSupportUnread(
  SupportUnreadState state,
  SupportUnreadEvent event,
) => switch ((state, event)) {
  (UnreadSignedOut(), UnreadAccessChanged(:final access)) =>
    switch (access.signedInSession) {
      null => state,
      final session => UnreadReading(session, 0),
    },
  (UnreadSession(:final session), UnreadAccessChanged(:final access)) =>
    switch (access.signedInSession) {
      null => const UnreadSignedOut(),
      final next when next == session => state,
      final next => UnreadReading(next, 0),
    },

  (UnreadSignedOut(), UnreadRecheckRequested()) => state,
  (UnreadReading(:final session, :final attempt), UnreadRecheckRequested()) =>
    UnreadReading(session, attempt + 1),
  (
    UnreadUnavailable(:final session, :final attempt),
    UnreadRecheckRequested(),
  ) =>
    UnreadReading(session, attempt + 1),
  (
    UnreadKnown(:final session, :final attempt, :final count) ||
        UnreadRefreshing(:final session, :final attempt, :final count) ||
        UnreadStale(:final session, :final attempt, :final count),
    UnreadRecheckRequested(),
  ) =>
    UnreadRefreshing(session, attempt + 1, count),
  // The read after marking sees whatever arrived meanwhile.
  (UnreadMarking(), UnreadRecheckRequested()) => state,

  (UnreadSignedOut(), UnreadChatShown()) => state,
  (UnreadSession(:final session, :final attempt), UnreadChatShown()) =>
    UnreadMarking(session, attempt + 1),

  (
    UnreadReading(:final session, :final attempt),
    UnreadCountAnswered(session: final from, attempt: final at, :final read),
  )
      when from == session && at == attempt =>
    _answered(
      read,
      got: (count) => UnreadKnown(session, attempt, count),
      failed: (problem) => UnreadUnavailable(session, attempt, problem),
    ),
  (
    UnreadRefreshing(:final session, :final attempt, :final count),
    UnreadCountAnswered(session: final from, attempt: final at, :final read),
  )
      when from == session && at == attempt =>
    _answered(
      read,
      got: (value) => UnreadKnown(session, attempt, value),
      failed: (problem) => UnreadStale(session, attempt, count, problem),
    ),
  (
    UnreadSignedOut() ||
        UnreadReading() ||
        UnreadUnavailable() ||
        UnreadKnown() ||
        UnreadRefreshing() ||
        UnreadStale() ||
        UnreadMarking(),
    UnreadCountAnswered(),
  ) =>
    state,

  (
    UnreadMarking(:final session, :final attempt),
    UnreadMarkAnswered(session: final from, attempt: final at, :final write),
  )
      when from == session && at == attempt =>
    switch (write) {
      // Confirmed with the server; the badge stays clear meanwhile.
      WriteDone() => UnreadRefreshing(session, attempt + 1, 0),
      // Not marked, or not known to be: read the real count.
      WriteRefused() ||
      WriteOutcomeUnknown() ||
      WriteNotSent() ||
      WriteSessionRejected() => UnreadReading(session, attempt + 1),
    },
  (
    UnreadSignedOut() ||
        UnreadReading() ||
        UnreadUnavailable() ||
        UnreadKnown() ||
        UnreadRefreshing() ||
        UnreadStale() ||
        UnreadMarking(),
    UnreadMarkAnswered(),
  ) =>
    state,
};

SupportUnreadState _answered(
  ExchangeRead<int> read, {
  required SupportUnreadState Function(int count) got,
  required SupportUnreadState Function(UnreadProblem problem) failed,
}) => switch (read) {
  ReadGot(:final value) => got(value),
  ReadMissing() => failed(UnreadProblem.missing),
  ReadUnreachable() => failed(UnreadProblem.unreachable),
  ReadMalformed() => failed(UnreadProblem.malformed),
  ReadSessionRejected() => failed(UnreadProblem.sessionRejected),
};

/// The count the chat icon shows; zero hides the badge. Nothing is shown
/// while the count is unknown or being marked read.
int supportUnreadBadge(SupportUnreadState state) => switch (state) {
  UnreadKnown(:final count) ||
  UnreadRefreshing(:final count) ||
  UnreadStale(:final count) => count,
  UnreadSignedOut() ||
  UnreadReading() ||
  UnreadUnavailable() ||
  UnreadMarking() => 0,
};
