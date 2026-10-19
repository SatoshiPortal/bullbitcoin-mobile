import 'dart:async';

import 'package:bull_payjoin/src/engine/payjoin_constants.dart';
import 'package:dio/dio.dart';

/// What one directory poll found, which decides what the poller does next.
enum DirectoryPollOutcome {
  /// The request or proposal arrived; polling stops and it is handed on.
  found,

  /// The directory answered that nothing is there yet.
  empty,

  /// A relay or protocol error; nothing is known about the mailbox.
  failed,

  /// The session's own expiry passed; polling stops and the expiry is handed
  /// on.
  expired,

  /// The session is no longer in the state this poll serves (another path
  /// moved it on).
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

/// One directory poll of a session; the poll passes [cancelToken] to its
/// requests.
typedef DirectoryPoll<T extends Object> =
    Future<DirectoryPollResult<T>> Function(CancelToken cancelToken);

/// Schedules the directory polls of one kind of session, keyed by session id.
///
/// Each session is polled on a fixed interval until a poll finds something or
/// the session's expiry passes. A tick that comes while the previous poll of
/// the session is still running is skipped.
final class DirectoryPoller<T extends Object> {
  final DateTime Function() _now;
  final Duration _interval;
  final Map<String, _PolledSession<T>> _sessions = {};

  // A slow poll (an unresponsive OHTTP relay) could otherwise overlap with the
  // next tick and hand the same request or proposal on twice.
  final Set<String> _inFlight = {};

  /// [now] reads the wall clock the session expiries are expressed in.
  DirectoryPoller({
    required this._now,
    this._interval = const Duration(
      seconds: PayjoinConstants.directoryPollingInterval,
    ),
  });

  /// Starts polling session [id] with [poll] until it finds something, its
  /// expiry at [expiresAt] passes, or [stop] is called. Starting a session
  /// that is already polled replaces it.
  void start({
    required String id,
    required DateTime expiresAt,
    required DirectoryPoll<T> poll,
    required void Function(T value) onFound,
    required void Function() onExpired,
  }) {
    _sessions.remove(id)?.timer?.cancel();
    final session = _PolledSession<T>(
      expiresAt: expiresAt,
      poll: poll,
      onFound: onFound,
      onExpired: onExpired,
    );
    _sessions[id] = session;
    session.timer = Timer.periodic(_interval, (_) => _tick(id, session));
  }

  /// Stops polling session [id]. A poll still in flight has its outcome
  /// dropped.
  void stop(String id) => _sessions.remove(id)?.timer?.cancel();

  /// Stops every session.
  void dispose() {
    for (final session in _sessions.values) {
      session.timer?.cancel();
    }
    _sessions.clear();
    _inFlight.clear();
  }

  Future<void> _tick(String id, _PolledSession<T> session) async {
    if (!_inFlight.add(id)) return;
    final DirectoryPollResult<T> result;
    try {
      result = _now().isAfter(session.expiresAt)
          ? DirectoryPollResult<T>(DirectoryPollOutcome.expired)
          : await session.poll(CancelToken());
    } catch (_) {
      return;
    } finally {
      _inFlight.remove(id);
    }
    // Stopped or restarted while this poll ran: the new owner decides.
    if (!identical(_sessions[id], session)) return;
    switch (result.outcome) {
      case DirectoryPollOutcome.found:
        _sessions.remove(id);
        session.timer?.cancel();
        if (result.value case final value?) session.onFound(value);
      case DirectoryPollOutcome.expired:
        _sessions.remove(id);
        session.timer?.cancel();
        session.onExpired();
      case DirectoryPollOutcome.empty:
      case DirectoryPollOutcome.failed:
      case DirectoryPollOutcome.stale:
        break;
    }
  }
}

final class _PolledSession<T extends Object> {
  final DateTime expiresAt;
  final DirectoryPoll<T> poll;
  final void Function(T value) onFound;
  final void Function() onExpired;

  /// Fires every interval until the session is settled or stopped.
  Timer? timer;

  _PolledSession({
    required this.expiresAt,
    required this.poll,
    required this.onFound,
    required this.onExpired,
  });
}
