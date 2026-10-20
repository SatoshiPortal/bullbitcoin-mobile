import 'dart:async';

import 'package:bull_payjoin/src/engine/payjoin_constants.dart';
import 'package:dio/dio.dart';

/// What one directory poll found, which decides when the next one goes out.
enum DirectoryPollOutcome {
  /// The request or proposal arrived; polling stops and it is handed on.
  found,

  /// The directory held the poll and answered that nothing is there yet.
  empty,

  /// A relay or protocol error; nothing is known about the mailbox.
  failed,

  /// The session's own expiry passed; polling stops and the expiry is handed
  /// on.
  expired,

  /// The session is no longer in the state this poll serves (another path
  /// moved it on); polling stops.
  stale,
}

/// The result of one directory poll: its outcome, and for [found] the value
/// that was found.
final class DirectoryPollResult<T extends Object> {
  final DirectoryPollOutcome outcome;
  final T? value;

  const DirectoryPollResult(this.outcome) : value = null;

  const DirectoryPollResult.found(T this.value)
    : outcome = DirectoryPollOutcome.found;
}

/// One directory poll of a session. [cancelToken] is cancelled when the
/// session ends while the poll is in flight, at its expiry or on [stop] or
/// [dispose]; the poll passes it to its requests. Once it is cancelled the
/// poller drops whatever the poll returns.
typedef DirectoryPoll<T extends Object> =
    Future<DirectoryPollResult<T>> Function(CancelToken cancelToken);

/// Schedules the directory polls of one kind of session, keyed by session id.
///
/// The schedule is payjoin-cli's: the first poll goes out at once, and the
/// next one follows a reply right away. The directory holds an empty GET for
/// up to 30 s (BIP 77), so the client adds no wait of its own. The one bound
/// is a minimum spacing between the starts of two polls of a session: a reply
/// the directory held satisfies it on its own, an empty reply that came back
/// early waits out the rest, and a failed poll waits it in full.
///
/// Each session also has a deadline of its own, independent of its polls: at
/// the session's expiry the poll in flight is cancelled, the next one is not
/// sent, and the expiry is handed on, once. The engine broadcasts the fallback
/// at that moment, so it must not depend on a poll being due.
final class DirectoryPoller<T extends Object> {
  final DateTime Function() _now;
  final Duration Function() _elapsed;
  final Duration _minSpacing;
  final Map<String, _PolledSession<T>> _sessions = {};

  // Completes when the poll in flight for a session id ends. A replacement
  // session waits for it, so two polls of one id never run at once and the
  // same request or proposal cannot be handed on twice.
  final Map<String, Future<void>> _inFlight = {};

  bool _disposed = false;

  /// [now] reads the wall clock the session expiries are expressed in.
  /// [elapsed] reads a monotonic clock, used to measure how long a poll took.
  DirectoryPoller({
    required this._now,
    required this._elapsed,
    this._minSpacing = const Duration(
      seconds: PayjoinConstants.directoryMinPollSpacingSec,
    ),
  });

  /// Starts polling session [id] with [poll] until it finds something, its
  /// expiry at [expiresAt] passes, or [stop] is called.
  ///
  /// Starting a session that is already polled leaves it as it is: the app
  /// resumes every open session each time it returns to the foreground, and
  /// that must neither abandon a held request nor cut a wait short. To
  /// replace a session, [stop] it first.
  void start({
    required String id,
    required DateTime expiresAt,
    required DirectoryPoll<T> poll,
    required void Function(T value) onFound,
    required void Function() onExpired,
  }) {
    if (_disposed || _sessions.containsKey(id)) return;
    final session = _PolledSession<T>(
      expiresAt: expiresAt,
      poll: poll,
      onFound: onFound,
      onExpired: onExpired,
    );
    _sessions[id] = session;
    final remaining = expiresAt.difference(_now());
    session.deadline = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () => _expire(id, session),
    );
    _arm(id, session, Duration.zero);
  }

  /// Stops polling session [id]. A poll still in flight is cancelled and its
  /// outcome dropped.
  void stop(String id) => _sessions.remove(id)?.end();

  /// Stops every session, cancels every poll in flight, and refuses new ones.
  void dispose() {
    _disposed = true;
    for (final session in _sessions.values) {
      session.end();
    }
    _sessions.clear();
  }

  void _arm(String id, _PolledSession<T> session, Duration delay) {
    session.next = Timer(delay, () => _run(id, session));
  }

  /// Ends session [id] at its expiry, provided [session] still owns it.
  void _expire(String id, _PolledSession<T> session) {
    if (!identical(_sessions[id], session)) return;
    _sessions.remove(id);
    session.end();
    session.onExpired();
  }

  Future<void> _run(String id, _PolledSession<T> session) async {
    final (result, took) = await _pollOnce(id, session);
    // Stopped or restarted while this poll ran: the new owner decides.
    if (!identical(_sessions[id], session)) return;
    // The expiry wins over anything the poll returned at or after it, even
    // when the poll's completion ran before the deadline timer.
    if (_hasExpired(session)) return _expire(id, session);
    switch (result.outcome) {
      case DirectoryPollOutcome.found:
        _sessions.remove(id);
        session.end();
        if (result.value case final value?) session.onFound(value);
      case DirectoryPollOutcome.expired:
        _expire(id, session);
      case DirectoryPollOutcome.stale:
        // Nothing left to poll for, but the session keeps its deadline: the
        // engine still has to settle it at its expiry.
        break;
      case DirectoryPollOutcome.failed:
        _arm(id, session, _minSpacing);
      case DirectoryPollOutcome.empty:
        _arm(
          id,
          session,
          took < _minSpacing ? _minSpacing - took : Duration.zero,
        );
    }
  }

  bool _hasExpired(_PolledSession<T> session) =>
      !session.expiresAt.isAfter(_now());

  /// Runs one poll of [session] and returns its result with how long the
  /// poll itself took, waiting for a replaced session's poll to unwind first.
  Future<(DirectoryPollResult<T>, Duration)> _pollOnce(
    String id,
    _PolledSession<T> session,
  ) async {
    final expired = DirectoryPollResult<T>(DirectoryPollOutcome.expired);
    // A poll of a replaced session may still be draining: its request was
    // cancelled, so this waits only for it to unwind.
    for (
      var previous = _inFlight[id];
      previous != null;
      previous = _inFlight[id]
    ) {
      await previous;
    }
    // Replaced again while waiting: the newer session polls instead.
    if (!identical(_sessions[id], session)) {
      return (
        DirectoryPollResult<T>(DirectoryPollOutcome.failed),
        Duration.zero,
      );
    }
    if (_hasExpired(session)) return (expired, Duration.zero);
    final done = Completer<void>();
    _inFlight[id] = done.future;
    final cancelToken = CancelToken();
    session.activeToken = cancelToken;
    final started = _elapsed();
    try {
      final result = await session.poll(cancelToken);
      return (result, _elapsed() - started);
    } catch (_) {
      return (
        DirectoryPollResult<T>(
          cancelToken.isCancelled
              ? DirectoryPollOutcome.expired
              : DirectoryPollOutcome.failed,
        ),
        _elapsed() - started,
      );
    } finally {
      session.activeToken = null;
      _inFlight.remove(id);
      done.complete();
    }
  }
}

final class _PolledSession<T extends Object> {
  final DateTime expiresAt;
  final DirectoryPoll<T> poll;
  final void Function(T value) onFound;
  final void Function() onExpired;

  /// The session's next poll, while it waits.
  Timer? next;

  /// Fires at the session's expiry, whatever the polls are doing.
  Timer? deadline;

  /// The token of the poll in flight, if any.
  CancelToken? activeToken;

  _PolledSession({
    required this.expiresAt,
    required this.poll,
    required this.onFound,
    required this.onExpired,
  });

  /// Cancels the session's timers and its poll in flight.
  void end() {
    next?.cancel();
    deadline?.cancel();
    activeToken?.cancel('payjoin session ended');
  }
}
