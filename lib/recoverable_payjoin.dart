import 'package:bull_payjoin/bull_payjoin.dart';
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

  RecoverablePayjoin(this._open);

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
    if (_disposed) return Err(_failure);

    // Unlike a role call, a resume retries an open that already failed: it is
    // the app's periodic recovery point (startup and every foreground return).
    await _ensureOpened();
    final lifecycle = _lifecycle;
    if (lifecycle == null) return Err(_failure);
    return lifecycle.resume();
  }

  /// Awaited by every role call, so a feature that runs while the app is still
  /// starting gets the real answer instead of the fail-closed placeholder.
  /// Returns immediately once an open has been attempted and failed — retrying
  /// per call would hammer unreadable storage; [resume] owns the retry.
  Future<void> _readyForRoleCall() {
    if (_disposed || _lifecycle != null) return Future<void>.value();
    final inFlight = _opening;
    if (inFlight != null) return inFlight;
    if (_openAttempted) return Future<void>.value();
    return _ensureOpened();
  }

  Future<void> _ensureOpened() {
    if (_disposed || _lifecycle != null) return Future<void>.value();
    final inFlight = _opening;
    if (inFlight != null) return inFlight;

    return _opening = _openAndClear();
  }

  Future<void> _openAndClear() async {
    try {
      switch (await _tryOpen()) {
        case Ok(:final value):
          if (_disposed) {
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
}

final class _RecoverablePayjoinSender implements PayjoinSender {
  final RecoverablePayjoin _owner;

  const _RecoverablePayjoinSender(this._owner);

  @override
  Future<Result<PayjoinSenderSession, PayjoinFailure>> start(
    StartPayjoinSender request,
  ) async {
    await _owner._readyForRoleCall();
    return _owner._delegate.sender.start(request);
  }

  @override
  Future<Result<PayjoinSession, PayjoinFailure>> broadcastOriginal(
    String sessionId,
  ) async {
    await _owner._readyForRoleCall();
    return _owner._delegate.sender.broadcastOriginal(sessionId);
  }

  @override
  Future<Result<bool, PayjoinFailure>> canBroadcastOriginal(
    String sessionId,
  ) async {
    await _owner._readyForRoleCall();
    return _owner._delegate.sender.canBroadcastOriginal(sessionId);
  }
}

final class _RecoverablePayjoinReceiver implements PayjoinReceiver {
  final RecoverablePayjoin _owner;

  const _RecoverablePayjoinReceiver(this._owner);

  @override
  Future<Result<PayjoinReceiverSession, PayjoinFailure>> start(
    StartPayjoinReceiver request,
  ) async {
    await _owner._readyForRoleCall();
    return _owner._delegate.receiver.start(request);
  }

  @override
  Future<Result<void, PayjoinFailure>> cancel(String sessionId) async {
    await _owner._readyForRoleCall();
    return _owner._delegate.receiver.cancel(sessionId);
  }

  @override
  Future<Result<void, PayjoinFailure>> disableAll() async {
    await _owner._readyForRoleCall();
    return _owner._delegate.receiver.disableAll();
  }
}

final class _RecoverablePayjoinSessions implements PayjoinSessions {
  final RecoverablePayjoin _owner;

  const _RecoverablePayjoinSessions(this._owner);

  @override
  Future<Result<PayjoinSession?, PayjoinFailure>> byId(String sessionId) async {
    await _owner._readyForRoleCall();
    return _owner._delegate.sessions.byId(sessionId);
  }

  @override
  Future<Result<List<PayjoinSession>, PayjoinFailure>> byTransactionId(
    String transactionId,
  ) async {
    await _owner._readyForRoleCall();
    return _owner._delegate.sessions.byTransactionId(transactionId);
  }

  @override
  Future<Result<List<PayjoinSession>, PayjoinFailure>> list(
    PayjoinSessionFilter filter,
  ) async {
    await _owner._readyForRoleCall();
    return _owner._delegate.sessions.list(filter);
  }

  @override
  Stream<Result<PayjoinSession, PayjoinFailure>> watch({
    Set<String>? sessionIds,
  }) async* {
    await _owner._readyForRoleCall();
    yield* _owner._delegate.sessions.watch(sessionIds: sessionIds);
  }

  @override
  Future<Result<Set<Outpoint>, PayjoinFailure>> reservedOutpoints() async {
    await _owner._readyForRoleCall();
    return _owner._delegate.sessions.reservedOutpoints();
  }
}

final class _RecoverablePayjoinPolicy implements PayjoinPolicyAccess {
  final RecoverablePayjoin _owner;

  const _RecoverablePayjoinPolicy(this._owner);

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> load() async {
    await _owner._readyForRoleCall();
    return _owner._delegate.policy.load();
  }

  @override
  Stream<Result<PayjoinPolicy, PayjoinFailure>> watch() async* {
    await _owner._readyForRoleCall();
    yield* _owner._delegate.policy.watch();
  }

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setEnabled(bool enabled) async {
    await _owner._readyForRoleCall();
    return _owner._delegate.policy.setEnabled(enabled);
  }

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setMinimumAmount(
    Sats amount,
  ) async {
    await _owner._readyForRoleCall();
    return _owner._delegate.policy.setMinimumAmount(amount);
  }

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> setSessionLifetime(
    Duration lifetime,
  ) async {
    await _owner._readyForRoleCall();
    return _owner._delegate.policy.setSessionLifetime(lifetime);
  }
}

final class _RecoverablePayjoinDiagnostics implements PayjoinDiagnostics {
  final RecoverablePayjoin _owner;

  const _RecoverablePayjoinDiagnostics(this._owner);

  @override
  Future<Result<PayjoinRelayHealth, PayjoinFailure>> relayHealth() async {
    await _owner._readyForRoleCall();
    return _owner._delegate.diagnostics.relayHealth();
  }
}
