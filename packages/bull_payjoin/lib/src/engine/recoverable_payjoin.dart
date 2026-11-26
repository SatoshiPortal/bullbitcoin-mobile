import 'dart:async';

import '../domain/payjoin_failure.dart';
import '../domain/payjoin_policy.dart';
import '../domain/payjoin_requests.dart';
import '../domain/payjoin_session.dart';
import '../public/payjoin.dart';
import '../public/payjoin_lifecycle.dart';
import '../public/payjoin_roles.dart';

import 'package:primitives/primitives.dart';

typedef PayjoinLifecycleOpener =
    Future<Result<PayjoinLifecycle, PayjoinFailure>> Function();

/// A [PayjoinLifecycle] that can be registered before its storage is open.
///
/// Opening the package database (and migrating the legacy tables into it) is
/// slow enough to be worth keeping off the pre-`runApp` path, and it can fail
/// on a device whose storage is momentarily unreadable. This wrapper is
/// therefore handed to the locator immediately and resolves its delegate
/// later, so every feature keeps the one role instance it was injected with
/// and sees it start working once the storage opens.
///
/// Two rules it must never break:
/// - **Fail-closed**: while the storage is unreadable the roles answer `Err`,
///   never an invented empty result. `reservedOutpoints()` in particular gates
///   coin selection, and a fabricated empty set would let a send spend an
///   outpoint reserved by a Payjoin session this build cannot read.
/// - **Open, then resume**: a role call waits for the *open* only. Resuming
///   sessions replays the directory and can rebroadcast, so it stays in the
///   background where a startup or foreground callback drives it.
final class RecoverablePayjoin implements PayjoinLifecycle {
  final PayjoinLifecycleOpener _open;
  final Future<bool> Function()? _isCurrent;
  late final Payjoin _publicPayjoin = Payjoin(
    sender: _RecoverablePayjoinSender(this),
    receiver: _RecoverablePayjoinReceiver(this),
    sessions: _RecoverablePayjoinSessions(this),
    policy: _RecoverablePayjoinPolicy(this),
    diagnostics: _RecoverablePayjoinDiagnostics(this),
  );
  Payjoin _delegate = Payjoin.unavailable(
    const PayjoinUnavailableFailure('Payjoin storage is still opening'),
  );
  PayjoinFailure _failure = const PayjoinUnavailableFailure(
    'Payjoin storage is still opening',
  );
  PayjoinLifecycle? _lifecycle;
  Future<void>? _opening;
  Future<Result<void, PayjoinFailure>>? _resuming;
  bool _openAttempted = false;
  bool _disposed = false;
  bool _suspended = false;
  Future<void>? _suspension;
  // Bumped by every revocation. Open, resume and role calls capture it before
  // their first await and give up when it moved.
  int _generation = 0;
  final _sensitive = <Future<void>>{};

  RecoverablePayjoin(this._open, {this._isCurrent});

  @override
  Payjoin get payjoin => _publicPayjoin;

  @override
  Future<Result<void, PayjoinFailure>> resume() {
    final inFlight = _resuming;
    if (inFlight != null) return inFlight;

    return _resuming = _resumeAndClear();
  }

  Future<Result<void, PayjoinFailure>> _resumeAndClear() async {
    try {
      return await _resume();
    } finally {
      _resuming = null;
    }
  }

  Future<Result<void, PayjoinFailure>> _resume() async {
    if (_disposed || _suspended) return Err(_failure);
    final generation = _generation;

    // Unlike a role call, a resume retries an open that already failed: it is
    // the app's periodic recovery point (startup and every foreground return).
    await _ensureOpened();
    if (!_live(generation)) return Err(_revoked);
    final current = _isCurrent;
    if (current != null && !await current()) {
      return const Err(
        PayjoinUnavailableFailure('Payjoin runtime family changed'),
      );
    }
    // A lock during either await revokes this resume before it replays.
    if (!_live(generation)) return Err(_revoked);
    final lifecycle = _lifecycle;
    if (lifecycle == null) return Err(_failure);
    return lifecycle.resume();
  }

  bool _live(int generation) =>
      !_disposed && !_suspended && generation == _generation;

  static const _revoked = PayjoinUnavailableFailure('Payjoin is suspended');

  /// Awaited by every role call, so a feature that runs while the app is still
  /// starting gets the real answer instead of the fail-closed placeholder.
  /// Returns immediately once an open has been attempted and failed — retrying
  /// per call would hammer unreadable storage; [resume] owns the retry.
  ///
  /// The answer is the role set of the generation the call began in. It is
  /// never stored: a lock during any await returns the unavailable set, so a
  /// revoked generation cannot reinstall a delegate.
  Future<Payjoin> _admit() async {
    final generation = _generation;
    if (_disposed || _suspended) return Payjoin.unavailable(_failure);
    if (_lifecycle == null) {
      final opening = _opening;
      if (opening != null) {
        await opening;
      } else if (!_openAttempted) {
        await _ensureOpened();
      }
    }
    if (!_live(generation)) return Payjoin.unavailable(_revoked);
    final lifecycle = _lifecycle;
    if (lifecycle == null) return _delegate;
    final current = _isCurrent;
    final stale = current != null && !await current();
    if (!_live(generation)) return Payjoin.unavailable(_revoked);
    return stale
        ? Payjoin.unavailable(
            const PayjoinUnavailableFailure('Payjoin runtime family changed'),
          )
        : lifecycle.payjoin;
  }

  /// A call that signs or publishes. It is registered before its first await,
  /// so a lock cannot confirm the stop beneath it. Admission is the moment it
  /// reaches the engine: a lock before that blocks it, a lock after leaves the
  /// engine's real result to the caller.
  Future<Result<T, PayjoinFailure>> _effect<T>(
    Future<Result<T, PayjoinFailure>> Function(Payjoin payjoin) run,
  ) {
    if (_disposed || _suspended) return Future.value(Err(_failure));
    final generation = _generation;
    final settled = Completer<void>();
    _sensitive.add(settled.future);
    return () async {
      try {
        final payjoin = await _admit();
        if (!_live(generation)) return Err<T, PayjoinFailure>(_revoked);
        return await run(payjoin);
      } finally {
        _sensitive.remove(settled.future);
        settled.complete();
      }
    }();
  }

  Future<void> _ensureOpened() {
    if (_disposed || _suspended || _lifecycle != null) {
      return Future<void>.value();
    }
    final inFlight = _opening;
    if (inFlight != null) return inFlight;

    return _opening = _openAndClear();
  }

  Future<void> _openAndClear() async {
    final generation = _generation;
    try {
      switch (await _tryOpen()) {
        case Ok(:final value):
          if (!_live(generation)) {
            await value.dispose();
            return;
          }
          _lifecycle = value;
          _delegate = value.payjoin;
        case Err(:final failure):
          _failure = failure;
          _delegate = Payjoin.unavailable(failure);
      }
    } finally {
      _openAttempted = true;
      _opening = null;
    }
  }

  Future<Result<PayjoinLifecycle, PayjoinFailure>> _tryOpen() async {
    try {
      return await _open();
    } catch (error) {
      return Err(PayjoinUnexpectedFailure(error.toString()));
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _failure = const PayjoinUnavailableFailure('Payjoin lifecycle is disposed');
    // An open or resume started before this call still owns the lifecycle it
    // is about to produce; let it settle so it is disposed rather than leaked.
    await _opening;
    await _resuming;
    await _lifecycle?.dispose();
    _lifecycle = null;
    _delegate = Payjoin.unavailable(_failure);
  }

  @override
  Future<void> suspend() {
    if (_disposed) return Future<void>.value();
    _suspended = true;
    _generation++;
    _failure = _revoked;
    _delegate = Payjoin.unavailable(_failure);
    return _suspension ??= _suspendAndClear();
  }

  Future<void> _suspendAndClear() async {
    try {
      // An open or resume already started owns the lifecycle it will produce:
      // let it settle so the storage is closed rather than leaked.
      await _opening;
      await _resuming;
      // Effects already admitted settle before the storage closes.
      while (_sensitive.isNotEmpty) {
        await Future.wait(_sensitive.toList());
      }
      final lifecycle = _lifecycle;
      _lifecycle = null;
      _delegate = Payjoin.unavailable(_failure);
      await lifecycle?.dispose();
    } finally {
      _suspension = null;
    }
  }

  @override
  void reopen() {
    // Only a confirmed stop lifts the suspension; no second instance opens
    // beside one that is still closing.
    if (!_suspended || _suspension != null) return;
    _suspended = false;
    _openAttempted = false;
    _failure = const PayjoinUnavailableFailure(
      'Payjoin storage is still opening',
    );
    _delegate = Payjoin.unavailable(_failure);
  }
}

final class _RecoverablePayjoinSender implements PayjoinSender {
  final RecoverablePayjoin _owner;

  const _RecoverablePayjoinSender(this._owner);

  @override
  Future<Result<PayjoinSession, PayjoinFailure>> retryProposal(
    String sessionId,
  ) async {
    return _owner._effect((payjoin) => payjoin.sender.retryProposal(sessionId));
  }

  @override
  Future<Result<PayjoinSenderSession, PayjoinFailure>> start(
    StartPayjoinSender request,
  ) async {
    return _owner._effect((payjoin) => payjoin.sender.start(request));
  }

  @override
  Future<Result<PayjoinSession, PayjoinFailure>> broadcastOriginal(
    String sessionId,
  ) async {
    return _owner._effect(
      (payjoin) => payjoin.sender.broadcastOriginal(sessionId),
    );
  }

  @override
  Future<Result<bool, PayjoinFailure>> canBroadcastOriginal(
    String sessionId,
  ) async {
    final payjoin = await _owner._admit();
    return payjoin.sender.canBroadcastOriginal(sessionId);
  }
}

final class _RecoverablePayjoinReceiver implements PayjoinReceiver {
  final RecoverablePayjoin _owner;

  const _RecoverablePayjoinReceiver(this._owner);

  @override
  Future<Result<PayjoinReceiverSession, PayjoinFailure>> start(
    StartPayjoinReceiver request,
  ) async {
    final payjoin = await _owner._admit();
    return payjoin.receiver.start(request);
  }

  @override
  Future<Result<void, PayjoinFailure>> cancel(String sessionId) async {
    final payjoin = await _owner._admit();
    return payjoin.receiver.cancel(sessionId);
  }

  @override
  Future<Result<void, PayjoinFailure>> disableAll() async {
    final payjoin = await _owner._admit();
    return payjoin.receiver.disableAll();
  }
}

final class _RecoverablePayjoinSessions implements PayjoinSessions {
  final RecoverablePayjoin _owner;

  const _RecoverablePayjoinSessions(this._owner);

  @override
  Future<Result<PayjoinSession?, PayjoinFailure>> byId(String sessionId) async {
    final payjoin = await _owner._admit();
    return payjoin.sessions.byId(sessionId);
  }

  @override
  Future<Result<List<PayjoinSession>, PayjoinFailure>> byTransactionId(
    String transactionId,
  ) async {
    final payjoin = await _owner._admit();
    return payjoin.sessions.byTransactionId(transactionId);
  }

  @override
  Future<Result<List<PayjoinSession>, PayjoinFailure>> list(
    PayjoinSessionFilter filter,
  ) async {
    final payjoin = await _owner._admit();
    return payjoin.sessions.list(filter);
  }

  @override
  Stream<Result<PayjoinSession, PayjoinFailure>> watch({
    Set<String>? sessionIds,
  }) async* {
    final payjoin = await _owner._admit();
    yield* payjoin.sessions.watch(sessionIds: sessionIds);
  }

  @override
  Future<Result<Set<Outpoint>, PayjoinFailure>> reservedOutpoints() async {
    final payjoin = await _owner._admit();
    return payjoin.sessions.reservedOutpoints();
  }

  @override
  Future<Result<String?, PayjoinFailure>> visibleTransaction(
    String sessionId,
  ) async {
    final payjoin = await _owner._admit();
    return payjoin.sessions.visibleTransaction(sessionId);
  }

  @override
  Future<Result<List<PayjoinInputReservation>, PayjoinFailure>>
  inputReservations() async {
    final payjoin = await _owner._admit();
    return payjoin.sessions.inputReservations();
  }
}

final class _RecoverablePayjoinPolicy implements PayjoinPolicyAccess {
  final RecoverablePayjoin _owner;

  const _RecoverablePayjoinPolicy(this._owner);

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> load() async {
    final payjoin = await _owner._admit();
    return payjoin.policy.load();
  }

  @override
  Stream<Result<PayjoinPolicy, PayjoinFailure>> watch() async* {
    final payjoin = await _owner._admit();
    yield* payjoin.policy.watch();
  }

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setActionEnabled(
    PayjoinAction action, {
    required bool enabled,
  }) async {
    final payjoin = await _owner._admit();
    return payjoin.policy.setActionEnabled(action, enabled: enabled);
  }

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setMinimumAmount(
    Sats amount,
  ) async {
    final payjoin = await _owner._admit();
    return payjoin.policy.setMinimumAmount(amount);
  }

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setSessionLifetime(
    Duration lifetime,
  ) async {
    final payjoin = await _owner._admit();
    return payjoin.policy.setSessionLifetime(lifetime);
  }
}

final class _RecoverablePayjoinDiagnostics implements PayjoinDiagnostics {
  final RecoverablePayjoin _owner;

  const _RecoverablePayjoinDiagnostics(this._owner);

  @override
  Future<Result<PayjoinRelayHealth, PayjoinFailure>> relayHealth() async {
    final payjoin = await _owner._admit();
    return payjoin.diagnostics.relayHealth();
  }
}
