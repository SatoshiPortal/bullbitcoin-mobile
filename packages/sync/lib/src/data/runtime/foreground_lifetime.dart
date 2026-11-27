import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart';

import '../../domain/sync_failure.dart';

/// Owns at most one foreground resource at a time, scoped to an exact grant.
///
/// The opener must return `Err` only when no resource remains owned. An
/// exception during opening leaves ownership unconfirmed and blocks remount.
/// The closer must return `Ok` only after actual closure is confirmed.
///
/// Clients must keep all admitted work inside the callback's future and not
/// await their own retirement from inside it. This fences admission and
/// returned values, not effects or events published by the callback itself.
final class ForegroundLifetime<R extends Object> {
  final ForegroundSession _session;
  final Future<Result<R, SyncFailure>> Function(SessionToken) _open;
  final Future<Result<void, SyncFailure>> Function(R) _close;
  late final StreamSubscription<SessionToken?> _changes;
  _Mount<R>? _mount;
  SyncFailure? _unconfirmed;
  Future<Result<void, SyncFailure>>? _stopping;

  ForegroundLifetime(
    this._session, {
    required this._open,
    required this._close,
  }) {
    _changes = _session.changes.listen((_) {
      if (_mount case final mount? when !_session.isCurrent(mount.grant)) {
        unawaited(_retire(mount));
      }
    });
  }

  bool get _available => _stopping == null && _unconfirmed == null;

  /// A grant to carry across awaits, not permission to recapture on failure.
  SessionToken? capture() => _available ? _session.capture() : null;

  /// Also usable as a synchronous fence at a deferred effect or publication.
  bool isCurrent(SessionToken token) => _available && _session.isCurrent(token);

  /// Waits for any outgoing mount, then admits only the captured [token].
  Future<Result<T, SyncFailure>> run<T>(
    SessionToken token,
    Future<Result<T, SyncFailure>> Function(R) work,
  ) async {
    if (!isCurrent(token)) return const Err(SyncClosedFailure());
    if (_mount case final outgoing? when !identical(outgoing.grant, token)) {
      await _retire(outgoing);
      if (!isCurrent(token)) return const Err(SyncClosedFailure());
    }

    // Register the mount before invoking the opener, which can yield or cause
    // a synchronous grant change. Recheck the grant at the actual invocation.
    final mount = _mount ??= _Mount(
      token,
      Future.microtask(() => _openIfCurrent(token)),
    );
    switch (await mount.opened) {
      case Err(:final failure):
        if (_unconfirmed == null &&
            mount.retiring == null &&
            identical(_mount, mount)) {
          _mount = null;
        }
        // An opening failure may itself contain details of the outgoing view.
        return _stopping == null && _session.isCurrent(token)
            ? Err(failure)
            : const Err(SyncClosedFailure());
      case Ok(:final value):
        if (!isCurrent(token)) return const Err(SyncClosedFailure());
        mount.admitted++;
        try {
          final result = await work(value);
          return isCurrent(token) ? result : const Err(SyncClosedFailure());
        } finally {
          mount.release();
        }
    }
  }

  Future<Result<R, SyncFailure>> _openIfCurrent(SessionToken token) async {
    if (!isCurrent(token)) return const Err(SyncClosedFailure());
    try {
      return await _open(token);
    } on Exception {
      const failure = SyncStorageFailure();
      _unconfirmed = failure;
      return const Err(failure);
    }
  }

  Future<Result<void, SyncFailure>> _retire(_Mount<R> mount) =>
      mount.retiring ??= _drainAndClose(mount);

  Future<Result<void, SyncFailure>> _drainAndClose(_Mount<R> mount) async {
    final opened = await mount.opened;
    if (_unconfirmed case final failure?) return Err(failure);
    if (opened case Ok(:final value)) {
      await mount.drain();
      try {
        if (await _close(value) case Err(:final failure)) {
          _unconfirmed = failure;
          return Err(failure);
        }
      } on Exception {
        const failure = SyncStorageFailure();
        _unconfirmed = failure;
        return const Err(failure);
      }
    }
    _mount = null;
    return const Ok(null);
  }

  /// Terminal and idempotent; distinct from a rotation or a lock.
  Future<Result<void, SyncFailure>> stop() {
    if (_stopping case final stopping?) return stopping;
    final stopped = Completer<Result<void, SyncFailure>>();
    _stopping = stopped.future;
    stopped.complete(_stop());
    return stopped.future;
  }

  Future<Result<void, SyncFailure>> _stop() async {
    final mount = _mount;
    final retiring = mount == null ? null : _retire(mount);
    await _changes.cancel();
    return retiring ?? const Ok(null);
  }
}

final class _Mount<R extends Object> {
  final SessionToken grant;
  final Future<Result<R, SyncFailure>> opened;
  Future<Result<void, SyncFailure>>? retiring;
  int admitted = 0;
  Completer<void>? _drained;

  _Mount(this.grant, this.opened);

  Future<void> drain() =>
      admitted == 0 ? Future.value() : (_drained ??= Completer()).future;

  void release() {
    if (--admitted == 0) _drained?.complete();
  }
}
