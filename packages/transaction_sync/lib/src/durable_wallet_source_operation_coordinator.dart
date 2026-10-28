import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart';

import 'wallet_source_key_hash.dart';
import 'wallet_source_operation_coordinator.dart';
import 'wallet_source_session.dart';

enum WalletCoordinationLogLevel { config, fine, warning }

final class WalletCoordinationLogEvent {
  final WalletCoordinationLogLevel level;
  final String message;

  const WalletCoordinationLogEvent(this.level, this.message);
}

typedef WalletCoordinationLogSink =
    void Function(WalletCoordinationLogEvent event);

final class DurableWalletSourceOperationCoordinator
    implements WalletSourceOperationCoordinator {
  final String databasePath;
  final String lockDirectoryPath;
  final Duration busyTimeout;
  final Duration pendingHeartbeatTimeout;
  final Duration? acquisitionTimeout;
  final int maxActiveSynchronizations;
  final WalletCoordinationLogSink? logSink;
  @visibleForTesting
  final void Function()? beforeClaimRelease;
  @visibleForTesting
  final Duration workerInitializationDelay;
  @visibleForTesting
  final bool failReleaseCleanup;
  @visibleForTesting
  final bool killWorkerAfterReady;
  @visibleForTesting
  final bool killWorkerBeforeReady;

  DurableWalletSourceOperationCoordinator({
    required this.databasePath,
    String? lockDirectoryPath,
    this.busyTimeout = const Duration(milliseconds: 250),
    // Well under the acquisition timeout: a request left by a killed process
    // blocks admission until it is purged. A waiting request refreshes its
    // heartbeat every few milliseconds and is restored if purged while
    // suspended.
    this.pendingHeartbeatTimeout = const Duration(seconds: 5),
    this.acquisitionTimeout = const Duration(seconds: 30),
    this.maxActiveSynchronizations = 2,
    this.logSink,
    @visibleForTesting this.beforeClaimRelease,
    @visibleForTesting this.workerInitializationDelay = Duration.zero,
    @visibleForTesting this.failReleaseCleanup = false,
    @visibleForTesting this.killWorkerAfterReady = false,
    @visibleForTesting this.killWorkerBeforeReady = false,
  }) : lockDirectoryPath =
           lockDirectoryPath ??
           '${File(databasePath).parent.path}/wallet-source-locks' {
    if (maxActiveSynchronizations <= 0) {
      throw ArgumentError.value(
        maxActiveSynchronizations,
        'maxActiveSynchronizations',
        'must be positive',
      );
    }
  }

  @override
  Future<T> runExclusive<T>(
    WalletSourceKey sourceKey,
    Future<T> Function(WalletSourceSession session) operation, {
    Duration? timeout = const Duration(seconds: 30),
    bool allowRetired = false,
    WalletOperationKind kind = WalletOperationKind.refresh,
    WalletOperationPriority priority = WalletOperationPriority.foreground,
  }) {
    final result = Completer<T>();
    unawaited(() async {
      try {
        await _execute(
          sourceKey,
          operation,
          timeout,
          allowRetired,
          kind,
          priority,
          result,
        );
      } catch (error, stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      }
    }());
    return result.future;
  }

  Future<void> _execute<T>(
    WalletSourceKey sourceKey,
    Future<T> Function(WalletSourceSession session) operation,
    Duration? timeout,
    bool allowRetired,
    WalletOperationKind kind,
    WalletOperationPriority priority,
    Completer<T> result,
  ) async {
    final operationToken = _newOperationToken();
    final stopwatch = Stopwatch()..start();
    final context = _logContext(operationToken, sourceKey, kind, priority);
    final traceLifecycle =
        kind == WalletOperationKind.synchronize ||
        kind == WalletOperationKind.discover;
    if (traceLifecycle) {
      _emitLog(
        WalletCoordinationLogLevel.config,
        'Wallet source operation queued $context capacity=$maxActiveSynchronizations',
      );
    }
    final keyHash = hashWalletSourceParts(
      sourceKey.walletId,
      sourceKey.chain,
      sourceKey.network,
    );
    late final _DurableActor actor;
    try {
      actor = await _DurableActor.start(
        databasePath: databasePath,
        lockDirectoryPath: lockDirectoryPath,
        busyTimeout: busyTimeout,
        pendingHeartbeatTimeout: pendingHeartbeatTimeout,
        acquisitionTimeout: acquisitionTimeout,
        maxActiveSynchronizations: maxActiveSynchronizations,
        keyHash: keyHash,
        kind: kind,
        priority: priority,
        allowRetired: allowRetired,
        workerInitializationDelay: workerInitializationDelay,
        failReleaseCleanup: failReleaseCleanup,
        killWorkerAfterReady: killWorkerAfterReady,
        killWorkerBeforeReady: killWorkerBeforeReady,
      );
    } catch (error) {
      _emitLog(
        WalletCoordinationLogLevel.warning,
        'Wallet source admission failed $context category=${_errorCategory(error)} wait_ms=${stopwatch.elapsedMilliseconds}',
      );
      rethrow;
    }
    if (traceLifecycle) {
      _emitLog(
        WalletCoordinationLogLevel.config,
        'Wallet source operation admitted $context generation=${actor.claim.generation} wait_ms=${stopwatch.elapsedMilliseconds}',
      );
    }
    final session = _DurableSession(actor);
    Timer? timer;
    late T value;
    Object? operationError;
    StackTrace? operationStack;
    var finished = false;
    var callerTimedOut = false;
    try {
      late Future<T> future;
      try {
        future = operation(session);
      } catch (error, stack) {
        future = Future<T>.error(error, stack);
      }
      if (timeout != null) {
        timer = Timer(timeout, () {
          if (!result.isCompleted) {
            callerTimedOut = true;
            _emitLog(
              WalletCoordinationLogLevel.warning,
              'Wallet source caller timed out $context elapsed_ms=${stopwatch.elapsedMilliseconds}',
            );
            result.completeError(
              TimeoutException('Wallet source operation timed out'),
            );
          }
        });
      }
      try {
        value = await future;
      } catch (error, stack) {
        operationError = error;
        operationStack = stack;
      }
      finished = true;
    } finally {
      timer?.cancel();
      // Only now has the callback settled: a dead worker's locks may go.
      actor.endOperation();
      Object? cleanupError;
      try {
        beforeClaimRelease?.call();
      } catch (error) {
        cleanupError = error;
      }
      try {
        await session.release();
      } catch (error) {
        cleanupError ??= error;
      }
      if (cleanupError != null) {
        _emitLog(
          WalletCoordinationLogLevel.warning,
          'Wallet source cleanup failed $context category=${_errorCategory(cleanupError)} elapsed_ms=${stopwatch.elapsedMilliseconds}',
        );
      }
      if (operationError != null) {
        _emitLog(
          WalletCoordinationLogLevel.warning,
          'Wallet source operation failed $context category=${_errorCategory(operationError)} elapsed_ms=${stopwatch.elapsedMilliseconds}',
        );
      } else if (cleanupError == null && finished && traceLifecycle) {
        _emitLog(
          WalletCoordinationLogLevel.fine,
          'Wallet source operation completed $context caller_timeout=$callerTimedOut elapsed_ms=${stopwatch.elapsedMilliseconds}',
        );
      }
      // The operation's outcome stands: a cleanup failure is logged above, and
      // the operation may already have published its result.
      if (finished && !result.isCompleted) {
        if (operationError != null) {
          result.completeError(operationError, operationStack);
        } else {
          result.complete(value);
        }
      }
    }
  }

  void _emitLog(WalletCoordinationLogLevel level, String message) {
    try {
      logSink?.call(WalletCoordinationLogEvent(level, message));
    } catch (_) {
      // Diagnostics must never alter synchronization behavior.
    }
  }
}

String _newOperationToken() {
  final random = Random.secure();
  return List.generate(
    8,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

String _logContext(
  String operationToken,
  WalletSourceKey sourceKey,
  WalletOperationKind kind,
  WalletOperationPriority priority,
) {
  final chain = switch (sourceKey.chain) {
    'bitcoin' => 'bitcoin',
    'liquid' => 'liquid',
    _ => 'unknown',
  };
  final network = switch (sourceKey.network) {
    'mainnet' => 'mainnet',
    'testnet' => 'testnet',
    'signet' => 'signet',
    'regtest' => 'regtest',
    _ => 'unknown',
  };
  return 'operation=$operationToken kind=${kind.name} priority=${priority.name} chain=$chain network=$network';
}

String _errorCategory(Object error) => switch (error) {
  TimeoutException() => 'timeout',
  SqliteException() => 'sqlite',
  FileSystemException() => 'filesystem',
  StateError(:final message) when message.contains('retired') => 'retired',
  StateError(:final message) when message.contains('superseded') =>
    'superseded',
  StateError(:final message) when message.contains('Unsupported') =>
    'unsupported-schema',
  StateError() => 'state',
  ArgumentError() => 'argument',
  _ => 'unexpected',
};

final class _DurableSession implements WalletSourceClaimedSession {
  final _DurableActor _actor;
  final WalletSourceClaim _sourceClaim;
  final List<Future<void>> _commands = [];
  bool _closed = false;

  _DurableSession(this._actor) : _sourceClaim = _actor.claim;

  @override
  WalletSourceClaim get claim => _sourceClaim;
  @override
  bool get isClosed => _closed;
  @override
  void ensureOpen() {
    if (_closed || _actor.isTerminal) {
      throw StateError('source session is closed');
    }
    // The actor holds the per-key BEGIN IMMEDIATE connection for this session.
    // Consequently this claim cannot be replaced until release is requested.
  }

  @override
  void retire() {
    ensureOpen();
    _queueCommand(_actor.setRetired(true));
  }

  @override
  void reactivate() {
    ensureOpen();
    _queueCommand(_actor.setRetired(false));
  }

  /// Awaited by [close]; a worker dying first fails it earlier, which must
  /// not surface as an unhandled error.
  void _queueCommand(Future<void> command) {
    unawaited(command.then<void>((_) {}, onError: (Object _) {}));
    _commands.add(command);
  }

  /// Ends the session's use by the operation. The source stays exclusive
  /// until the coordinator sees the operation callback settle.
  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait(_commands);
  }

  /// Called by the coordinator once the operation callback has settled.
  Future<void> release() async {
    Object? firstError;
    try {
      await close();
    } catch (error) {
      firstError = error;
    }
    try {
      await _actor.release();
    } catch (error) {
      firstError ??= error;
    }
    if (firstError != null) throw firstError;
  }
}

final class _DurableActor {
  static final Map<String, Future<void>> _registrationTails = {};
  final SendPort _port;
  final Stream<Object?> _responses;
  final ReceivePort _receivePort;
  final Isolate _isolate;
  final ReceivePort _exitPort;
  final WalletSourceClaim claim;
  int _id = 0;
  final Map<int, Completer<Object?>> _pending = {};
  bool _closed = false;
  Object? _terminalError;

  final _LockOwner _locks;

  _DurableActor(
    this._port,
    this._responses,
    this._receivePort,
    this._isolate,
    this._exitPort,
    this.claim,
    this._locks,
  ) {
    _responses.listen((message) {
      if (message is! List || message.length < 3) return;
      final completer = _pending.remove(message[0] as int);
      if (completer == null) return;
      if (message[1] == true) {
        completer.complete(message[2]);
      } else {
        completer.completeError(_workerError(message[2] as String));
      }
    });
    _exitPort.listen((_) {
      _markTerminal(StateError('Wallet source coordination worker exited'));
    });
  }

  bool get isTerminal => _closed;

  /// Called by the coordinator once the operation callback has settled.
  void endOperation() => _locks.endOperation();

  static Future<_DurableActor> start({
    required String databasePath,
    required String lockDirectoryPath,
    required Duration busyTimeout,
    required Duration pendingHeartbeatTimeout,
    required Duration? acquisitionTimeout,
    required int maxActiveSynchronizations,
    required String keyHash,
    required WalletOperationKind kind,
    required WalletOperationPriority priority,
    required bool allowRetired,
    required Duration workerInitializationDelay,
    required bool failReleaseCleanup,
    required bool killWorkerAfterReady,
    required bool killWorkerBeforeReady,
  }) async {
    final global =
        kind == WalletOperationKind.synchronize ||
        kind == WalletOperationKind.discover;
    final busy = busyTimeout.inMilliseconds;
    // The registration order is reserved before anything asynchronous runs.
    final registrationKey = '$databasePath\u0000$keyHash';
    final previousRegistration =
        _registrationTails[registrationKey] ?? Future<void>.value();
    final registered = Completer<void>();
    late final Future<void> registrationTail;
    registrationTail = registered.future.whenComplete(() {});
    _registrationTails[registrationKey] = registrationTail;
    // A start that fails before registering gives its place up only once its
    // predecessor has registered, so a later start cannot overtake that one.
    void giveUpRegistration() {
      previousRegistration.whenComplete(() {
        if (!registered.isCompleted) registered.complete();
        if (identical(_registrationTails[registrationKey], registrationTail)) {
          _registrationTails.remove(registrationKey);
        }
      });
    }

    late final _LockOwner locks;
    try {
      final addresses = await _openLockConnectionsAside(
        lockDirectoryPath,
        keyHash,
        busy,
        global ? maxActiveSynchronizations : 0,
      );
      locks = _LockOwner(databasePath, busy, _token(), addresses);
    } catch (_) {
      giveUpRegistration();
      rethrow;
    }
    final responses = ReceivePort();
    final exitPort = ReceivePort();
    final handshakeExit = ReceivePort();
    final responseStream = responses.asBroadcastStream();
    final ready = Completer<List<Object?>>();
    late final Isolate isolate;
    try {
      isolate = await Isolate.spawn(_workerMain, [
        responses.sendPort,
        databasePath,
        lockDirectoryPath,
        busyTimeout.inMilliseconds,
        pendingHeartbeatTimeout.inMilliseconds,
        acquisitionTimeout?.inMilliseconds,
        maxActiveSynchronizations,
        keyHash,
        kind.name,
        priority.name,
        allowRetired,
        workerInitializationDelay.inMilliseconds,
        failReleaseCleanup,
        responses.sendPort,
        killWorkerAfterReady,
        killWorkerBeforeReady,
        locks.request,
        locks.addresses,
        locks.exitPort.sendPort,
        // Without capabilities: the worker may only watch the caller exit.
        Isolate(Isolate.current.controlPort),
      ]);
    } catch (_) {
      responses.close();
      exitPort.close();
      handshakeExit.close();
      locks.abandon();
      giveUpRegistration();
      rethrow;
    }
    isolate.addOnExitListener(exitPort.sendPort);
    isolate.addOnExitListener(handshakeExit.sendPort);
    isolate.addOnExitListener(locks.exitPort.sendPort);
    late StreamSubscription<Object?> subscription;
    final handshakeExitSubscription = handshakeExit.listen((_) {
      if (!ready.isCompleted) {
        ready.completeError(
          StateError('Wallet source coordination worker exited'),
        );
      }
      giveUpRegistration();
    });
    subscription = responseStream.listen((message) {
      if (message is List && message.isNotEmpty && message[0] == 'register') {
        final reply = message[1] as SendPort;
        previousRegistration.whenComplete(() => reply.send(null));
      } else if (message is List &&
          message.isNotEmpty &&
          message[0] == 'registered') {
        registered.complete();
      } else if (message is List &&
          message.isNotEmpty &&
          message[0] == 'ready') {
        ready.complete(message.cast<Object?>());
        subscription.cancel();
      } else if (message is List &&
          message.isNotEmpty &&
          message[0] == 'error') {
        ready.completeError(_workerError(message[1] as String));
        subscription.cancel();
      }
    });
    try {
      final data = await ready.future;
      locks.adoptClaim(keyHash, data[2] as int, data[3] as String);
      final actor = _DurableActor(
        data[1] as SendPort,
        responseStream,
        responses,
        isolate,
        exitPort,
        WalletSourceClaim(
          key: keyHash,
          generation: data[2] as int,
          ownerToken: data[3] as String,
          kind: kind,
          priority: priority,
        ),
        locks,
      );
      await handshakeExitSubscription.cancel();
      handshakeExit.close();
      if (identical(_registrationTails[registrationKey], registrationTail)) {
        _registrationTails.remove(registrationKey);
      }
      return actor;
    } catch (_) {
      await subscription.cancel();
      await handshakeExitSubscription.cancel();
      responses.close();
      exitPort.close();
      handshakeExit.close();
      giveUpRegistration();
      // No operation ran: the locks go as soon as the worker is gone.
      locks.endOperation();
      isolate.kill(priority: Isolate.immediate);
      await locks.settled;
      rethrow;
    }
  }

  Future<void> setRetired(bool retired) =>
      _command('retire', retired).then((_) {});
  Future<void> release() async {
    if (_closed) {
      await _locks.settled;
      if (_terminalError case final error?) throw error;
      return;
    }
    Object? error;
    try {
      await _command('release');
    } catch (caught) {
      error = caught;
    }
    try {
      await _command('terminate');
    } catch (caught) {
      error ??= caught;
    } finally {
      _markTerminal(error);
      // Killing a worker that is still finishing its cleanup would leak the
      // connections it holds; it exits by itself right after acknowledging.
      await _locks.exited.timeout(
        const Duration(seconds: 2),
        onTimeout: () => _isolate.kill(priority: Isolate.immediate),
      );
      await _locks.settled;
    }
    if (error != null) throw error;
  }

  Future<Object?> _command(String command, [Object? argument]) {
    if (_closed) {
      return Future<Object?>.error(
        _terminalError ?? StateError('Wallet source actor closed'),
      );
    }
    final id = ++_id;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _port.send([id, command, argument]);
    return completer.future;
  }

  void _failPending(Object error) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
  }

  void _markTerminal(Object? error) {
    if (_closed) return;
    _closed = true;
    _terminalError = error;
    _failPending(error ?? StateError('Wallet source actor closed'));
    _receivePort.close();
    _exitPort.close();
  }
}

/// Owns a worker's lock connections and queue request from their creation:
/// the connections are opened outside the killable worker and the request
/// token is chosen here, so nothing depends on the worker surviving. They are
/// closed and removed once the worker has exited and the coordinator has seen
/// the operation callback settle: a dead worker can neither keep the locks nor
/// free them while its operation still runs.
final class _LockOwner {
  final String _databasePath;
  final int _busy;
  final String request;
  final List<int> addresses;
  final ReceivePort exitPort = ReceivePort();
  final Completer<void> _exited = Completer<void>();
  final Completer<void> _settled = Completer<void>();
  bool _requestCleaned = false;
  bool _operationEnded = false;
  bool _closed = false;
  _ClaimRow? _claim;

  /// The worker reports the removal of its request on [exitPort], which also
  /// receives its exit: one port keeps the report ahead of the exit.
  _LockOwner(this._databasePath, this._busy, this.request, this.addresses) {
    exitPort.listen((message) {
      if (message == 'cleaned') {
        _requestCleaned = true;
        return;
      }
      exitPort.close();
      if (!_exited.isCompleted) _exited.complete();
      _closeWhenSettled();
    });
  }

  Future<void> get exited => _exited.future;

  /// Completes once the locks are closed and a stranded request is removed.
  Future<void> get settled => _settled.future;

  void endOperation() {
    _operationEnded = true;
    _closeWhenSettled();
  }

  /// The claim the worker activated; removed with the request if the worker
  /// dies, since a leftover claim keeps its key out of global admission.
  void adoptClaim(String keyHash, int generation, String ownerToken) {
    _claim = (keyHash: keyHash, generation: generation, ownerToken: ownerToken);
  }

  /// For a worker that never started: nothing else will close the locks.
  void abandon() {
    exitPort.close();
    if (!_exited.isCompleted) _exited.complete();
    _requestCleaned = true;
    endOperation();
  }

  void _closeWhenSettled() {
    if (_closed || !_exited.isCompleted || !_operationEnded) return;
    _closed = true;
    for (final address in addresses) {
      try {
        // Closing rolls back a held transaction, which releases the lock.
        sqlite3.fromPointer(Pointer<Void>.fromAddress(address)).dispose();
      } catch (_) {
        // The process keeps the lock until it exits, as before.
      }
    }
    if (_requestCleaned) {
      _settled.complete();
      return;
    }
    // A request left by the worker would head the shared queue and hold back
    // every wallet until its heartbeat expires, and its claim would keep the
    // key out of global admission. Removed off this isolate, which may be the
    // UI's, retrying through contention, and never recreating a deleted
    // database; the caller waits for it one second at most.
    _removeRequestAside(_databasePath, _busy, request, _claim)
        .timeout(const Duration(seconds: 1), onTimeout: () {})
        .whenComplete(_settled.complete);
  }
}

typedef _ClaimRow = ({String keyHash, int generation, String ownerToken});

/// Removes a request row and its claim in its own isolate, retrying for up to
/// 30 s while the coordination database is busy.
Future<void> _removeRequestAside(
  String path,
  int busy,
  String token,
  _ClaimRow? claim,
) =>
    Isolate.run(() {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (true) {
        final db = sqlite3.open(path, mode: OpenMode.readWrite);
        try {
          db.execute('PRAGMA busy_timeout = $busy');
          db.execute('DELETE FROM requests WHERE request_token=?', [token]);
          if (claim != null) {
            db.execute(
              'DELETE FROM claims WHERE key_hash=? AND generation=? AND owner_token=?',
              [claim.keyHash, claim.generation, claim.ownerToken],
            );
          }
          return;
        } catch (error) {
          if (!_isRetryable(error) || DateTime.now().isAfter(deadline)) {
            return;
          }
        } finally {
          db.dispose();
        }
        sleep(const Duration(milliseconds: 100));
      }
    }).catchError((Object _) {
      // The database is gone; nothing is left to remove.
    });

/// Runs [_openLockConnections] in its own isolate; a separate function so the
/// closure captures only these values.
Future<List<int>> _openLockConnectionsAside(
  String locks,
  String hash,
  int busy,
  int slots,
) => Isolate.run(() => _openLockConnections(locks, hash, busy, slots));

/// Opens the key connection and, for a synchronization, every slot
/// connection; runs in a short-lived isolate that is never killed, so the
/// connections exist only once their addresses reach the caller.
List<int> _openLockConnections(String locks, String hash, int busy, int slots) {
  Directory(locks).createSync(recursive: true);
  final opened = <Database>[];
  try {
    for (final file in [
      '$locks/$hash.sqlite',
      for (var index = 0; index < slots; index++)
        '$locks/synchronization-slot-$index.sqlite',
    ]) {
      final db = sqlite3.open(file);
      opened.add(db);
      db.execute('PRAGMA busy_timeout = $busy');
    }
  } catch (_) {
    for (final db in opened) {
      db.dispose();
    }
    rethrow;
  }
  // Not disposed: this isolate exits now and its finalizers do not run.
  return [for (final db in opened) db.handle.address];
}

Object _workerError(String category) => switch (category) {
  'admission-timeout' => TimeoutException('Wallet source admission timed out'),
  'retired' => StateError('wallet source is retired'),
  'superseded' => StateError('coordinator request superseded'),
  'unsupported-schema' => StateError('Unsupported coordinator schema'),
  'filesystem' => FileSystemException('Wallet source coordination failed'),
  'state' => StateError('Wallet source coordination state failed'),
  'type' => StateError('Wallet source coordination type failed'),
  'argument' => StateError('Wallet source coordination argument failed'),
  _ => WalletSourceCoordinationException(category),
};

enum WalletSourceCoordinationCategory { busy, coordination }

final class WalletSourceCoordinationException implements Exception {
  final WalletSourceCoordinationCategory category;
  WalletSourceCoordinationException(String value)
    : category = value == 'busy'
          ? WalletSourceCoordinationCategory.busy
          : WalletSourceCoordinationCategory.coordination;

  @override
  String toString() => 'Wallet source coordination failed (${category.name})';
}

Future<void> _workerMain(List<Object?> args) async {
  final out = args[0] as SendPort;
  final dbPath = args[1] as String;
  final lockPath = args[2] as String;
  final busy = args[3] as int;
  final stale = args[4] as int;
  final acquisition = args[5] as int?;
  final maxActiveSynchronizations = args[6] as int;
  final hash = args[7] as String;
  final initializationDelay = args[11] as int;
  final failReleaseCleanup = args[12] as bool;
  final killWorkerAfterReady = args[14] as bool;
  final killWorkerBeforeReady = args[15] as bool;
  final request = args[16] as String;
  final lockOwner = args[18] as SendPort;
  // Owned and closed by the caller; kept referenced so no finalizer closes
  // them before this isolate exits. sqlite3's dispose finalizer is a Dart
  // `Finalizer`, which runs only in the isolate that attached it, never after
  // that isolate has exited: the caller's close is the only close, unless
  // the caller exits first.
  final lockConnections = [
    for (final address in (args[17] as List).cast<int>())
      sqlite3.fromPointer(Pointer<Void>.fromAddress(address)),
  ];
  _handedOverLocks.addAll(lockConnections);
  final commands = ReceivePort();
  // A caller destroyed with its engine, as when Android stops a background
  // job, never closes these connections, so their locks would outlive it
  // until the process dies. The worker then releases and closes them itself.
  final caller = args[19] as Isolate;
  caller.addOnExitListener(commands.sendPort, response: _callerExited);
  var callerExited = false;
  ReceivePort? registrationReply;
  Database? mutex;
  Database? slot;
  WalletSourceClaim? claim;
  var readySent = false;
  String? failedAdmissionCategory;
  var awaitingTermination = false;
  // The caller closes the lock connections; here they are only rolled back,
  // which frees the locks. Done once: a repeat after release could outlast
  // the caller's wait under contention.
  var cleanedUp = false;
  void closeLocks() {
    if (cleanedUp) return;
    cleanedUp = true;
    if (_bestEffortCleanup(dbPath, busy, hash, request, claim, mutex, slot)) {
      lockOwner.send('cleaned');
    }
    mutex = null;
    slot = null;
  }

  try {
    final reply = ReceivePort();
    registrationReply = reply;
    out.send(['register', reply.sendPort]);
    await reply.first;
    reply.close();
    registrationReply = null;
    Directory(File(dbPath).parent.path).createSync(recursive: true);
    _initialize(dbPath, busy, maxActiveSynchronizations);
    final requestedAt = _now();
    _central(
      dbPath,
      busy,
      (db) => db.execute(
        '''INSERT INTO requests
        (request_token, key_hash, kind, priority, status, requested_at, heartbeat_at)
        VALUES (?,?,?,?,?,?,?)''',
        [request, hash, args[8], args[9], 'pending', requestedAt, _now()],
      ),
    );
    out.send(['registered']);
    if (initializationDelay > 0) {
      sleep(Duration(milliseconds: initializationDelay));
    }
    final acquired = _acquire(
      dbPath,
      lockPath,
      hash,
      request,
      busy,
      stale,
      acquisition,
      maxActiveSynchronizations,
      args[8] as String,
      args[9] as String,
      requestedAt,
      key: lockConnections.first,
      slots: lockConnections.skip(1).toList(),
    );
    final keyLock = acquired.key;
    final slotLock = acquired.slot;
    mutex = keyLock;
    slot = slotLock;
    if (killWorkerBeforeReady) {
      Isolate.current.kill(priority: Isolate.immediate);
      return;
    }
    claim = _activate(
      dbPath,
      busy,
      hash,
      request,
      args[8] as String,
      args[9] as String,
      args[10] as bool,
    );
    out.send(['ready', commands.sendPort, claim.generation, claim.ownerToken]);
    readySent = true;
    if (killWorkerAfterReady) {
      Isolate.current.kill(priority: Isolate.immediate);
      return;
    }
    await for (final message in commands) {
      if (message == _callerExited) {
        callerExited = true;
        break;
      }
      final reply = message[0] as int;
      try {
        switch (message[1] as String) {
          case 'retire':
            _central(
              dbPath,
              busy,
              (db) => db.execute(
                'INSERT OR REPLACE INTO source_state VALUES (?,?)',
                [hash, (message[2] as bool) ? 1 : 0],
              ),
            );
          case 'release':
            if (failReleaseCleanup) {
              throw StateError('injected release cleanup failure');
            }
            closeLocks();
            claim = null;
            mutex = null;
            slot = null;
            awaitingTermination = true;
          case 'terminate':
            if (!awaitingTermination) {
              throw StateError('unexpected actor termination');
            }
          default:
            throw StateError('unknown command');
        }
        out.send([reply, true, null]);
        if (message[1] == 'terminate') {
          break;
        }
      } catch (error) {
        if (message[1] == 'release') {
          closeLocks();
          claim = null;
          mutex = null;
          slot = null;
          awaitingTermination = true;
        }
        out.send([reply, false, _category(error)]);
        if (message[1] == 'terminate') {
          break;
        }
      }
    }
  } catch (error) {
    if (!readySent) {
      failedAdmissionCategory = _category(error);
    }
  } finally {
    closeLocks();
    caller.removeOnExitListener(commands.sendPort);
    if (callerExited) {
      for (final connection in lockConnections) {
        connection.dispose();
      }
    }
    registrationReply?.close();
    commands.close();
    // The caller terminates a failed startup worker as soon as it receives
    // this reply. Release SQLite locks first so a rejected retired-source
    // operation cannot strand its mutex and block the next reactivation.
    if (failedAdmissionCategory != null) {
      out.send(['error', failedAdmissionCategory]);
    }
  }
}

const _callerExited = 'caller-exited';

/// Lock connections whose closing belongs to the caller, kept referenced so
/// no finalizer closes them before this worker isolate exits.
final List<Database> _handedOverLocks = [];

/// Returns whether the request row was removed, so a failed removal can be
/// left to the caller.
bool _bestEffortCleanup(
  String dbPath,
  int busy,
  String hash,
  String request,
  WalletSourceClaim? claim,
  Database? mutex,
  Database? slot,
) {
  try {
    if (claim != null) {
      _central(
        dbPath,
        busy,
        (db) => db.execute(
          'DELETE FROM claims WHERE key_hash=? AND generation=? AND owner_token=?',
          [hash, claim.generation, claim.ownerToken],
        ),
      );
    }
  } catch (_) {}
  var requestRemoved = false;
  try {
    _central(
      dbPath,
      busy,
      (db) =>
          db.execute('DELETE FROM requests WHERE request_token=?', [request]),
    );
    requestRemoved = true;
  } catch (_) {}
  if (slot != null) {
    try {
      slot.execute('ROLLBACK');
    } catch (_) {}
  }
  if (mutex != null) {
    try {
      mutex.execute('ROLLBACK');
    } catch (_) {}
  }
  return requestRemoved;
}

String _category(Object error) {
  if (error is TimeoutException) return 'admission-timeout';
  if (error is SqliteException &&
      (error.resultCode == SqlError.SQLITE_BUSY ||
          error.resultCode == SqlError.SQLITE_LOCKED)) {
    return 'busy';
  }
  if (error is SqliteException) return 'sqlite';
  if (error is NoSuchMethodError) return 'no-such-method';
  if (error is FileSystemException) return 'filesystem';
  if (error is TypeError) return 'type';
  if (error is ArgumentError) return 'argument';
  // The specific refusals are StateErrors too: test them first so the caller
  // learns which one happened.
  final text = error.toString();
  if (text.contains('retired')) return 'retired';
  if (text.contains('superseded')) return 'superseded';
  if (text.contains('Unsupported')) return 'unsupported-schema';
  if (error is StateError) return 'state';
  return 'coordination';
}

void _initialize(String path, int busy, int capacity) => _central(path, busy, (
  db,
) {
  db.execute('PRAGMA journal_mode = WAL');
  db.execute('BEGIN IMMEDIATE');
  try {
    if ((db.select('PRAGMA user_version').single['user_version'] as int) > 1) {
      throw StateError('Unsupported coordinator schema');
    }
    db.execute(
      'CREATE TABLE IF NOT EXISTS generations (key_hash TEXT PRIMARY KEY, generation INTEGER NOT NULL)',
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS claims (key_hash TEXT PRIMARY KEY, generation INTEGER NOT NULL, owner_token TEXT NOT NULL, kind TEXT NOT NULL, priority TEXT NOT NULL, claimed_at INTEGER NOT NULL)',
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS requests (request_token TEXT PRIMARY KEY, key_hash TEXT NOT NULL, priority TEXT NOT NULL, status TEXT NOT NULL, requested_at INTEGER NOT NULL, heartbeat_at INTEGER NOT NULL)',
    );
    final columns = db.select('PRAGMA table_info(requests)');
    if (!columns.any((row) => row['name'] == 'kind')) {
      db.execute(
        "ALTER TABLE requests ADD COLUMN kind TEXT NOT NULL DEFAULT 'refresh'",
      );
    }
    db.execute(
      'CREATE TABLE IF NOT EXISTS coordinator_config (id INTEGER PRIMARY KEY CHECK (id=1), max_active_synchronizations INTEGER NOT NULL)',
    );
    final config = db.select(
      'SELECT max_active_synchronizations FROM coordinator_config WHERE id=1',
    );
    if (config.isEmpty) {
      db.execute('INSERT INTO coordinator_config VALUES (1, ?)', [capacity]);
    } else if (config.single['max_active_synchronizations'] != capacity) {
      throw ArgumentError(
        'Coordinator capacity does not match the shared database',
      );
    }
    db.execute(
      'CREATE TABLE IF NOT EXISTS source_state (key_hash TEXT PRIMARY KEY, retired INTEGER NOT NULL)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS requests_admission_idx ON requests (key_hash, status, priority, requested_at, request_token)',
    );
    db.execute('PRAGMA user_version = 1');
    db.execute('COMMIT');
  } catch (_) {
    try {
      db.execute('ROLLBACK');
    } catch (_) {}
    rethrow;
  }
});

({Database key, Database? slot}) _acquire(
  String central,
  String locks,
  String hash,
  String request,
  int busy,
  int stale,
  int? timeout,
  int capacity,
  String kind,
  String priority,
  int requestedAt, {
  required Database key,
  required List<Database> slots,
}) {
  final deadline = timeout == null
      ? null
      : DateTime.now().add(Duration(milliseconds: timeout));
  final global =
      kind == WalletOperationKind.synchronize.name ||
      kind == WalletOperationKind.discover.name;
  final background = priority == WalletOperationPriority.background.name;
  final row = (
    hash: hash,
    kind: kind,
    priority: priority,
    requestedAt: requestedAt,
  );
  // Attempts reuse the caller-owned connections with BEGIN IMMEDIATE and
  // ROLLBACK; they are never closed here.
  void rollback(Database db) {
    try {
      db.execute('ROLLBACK');
    } catch (_) {}
  }

  while (true) {
    if (deadline != null && !DateTime.now().isBefore(deadline)) {
      _central(
        central,
        busy,
        (db) => db.execute(
          "DELETE FROM requests WHERE request_token=? AND status='pending'",
          [request],
        ),
      );
      throw TimeoutException('Wallet source admission timed out');
    }
    if (_admit(central, busy, row, request, stale, global)) {
      Database? slot;
      try {
        key.execute('BEGIN IMMEDIATE');
        if (_admit(central, busy, row, request, stale, global)) {
          if (!global) return (key: key, slot: null);
          slot = _tryAcquireSlot(slots, background: background);
          if (slot != null &&
              _admit(central, busy, row, request, stale, global)) {
            return (key: key, slot: slot);
          }
        }
      } catch (error) {
        if (!_isRetryable(error)) rethrow;
      }
      if (slot != null) rollback(slot);
      rollback(key);
    }
    sleep(const Duration(milliseconds: 20));
  }
}

/// With two slots or more, the first is kept for foreground work: background
/// scans can never hold every slot while the user waits. A single slot is
/// shared, ordered foreground first by admission.
Database? _tryAcquireSlot(List<Database> slots, {required bool background}) {
  for (final db in background && slots.length > 1 ? slots.skip(1) : slots) {
    try {
      db.execute('BEGIN IMMEDIATE');
      return db;
    } catch (error) {
      if (!_isRetryable(error)) rethrow;
    }
  }
  return null;
}

typedef _RequestRow = ({
  String hash,
  String kind,
  String priority,
  int requestedAt,
});

/// Re-creates this live request's row after another worker purged it as
/// stale, as happens when the device was suspended longer than the heartbeat
/// timeout; the original order is kept.
void _restoreRequest(Database db, _RequestRow row, String request) {
  db.execute(
    '''INSERT OR IGNORE INTO requests
    (request_token, key_hash, kind, priority, status, requested_at, heartbeat_at)
    VALUES (?,?,?,?,?,?,?)''',
    [
      request,
      row.hash,
      row.kind,
      row.priority,
      'pending',
      row.requestedAt,
      _now(),
    ],
  );
  if (db.updatedRows != 1) {
    throw StateError('coordinator request superseded');
  }
}

bool _admit(
  String path,
  int busy,
  _RequestRow row,
  String request,
  int stale,
  bool global,
) {
  final hash = row.hash;
  var admitted = false;
  _central(path, busy, (db) {
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute(
        "UPDATE requests SET heartbeat_at=? WHERE request_token=? AND status='pending'",
        [_now(), request],
      );
      if (db.updatedRows != 1) _restoreRequest(db, row, request);
      db.execute(
        "DELETE FROM requests WHERE status='pending' AND heartbeat_at < ? AND request_token <> ?",
        [_now() - stale, request],
      );
      final rows = db.select(
        global
            ? '''
        SELECT request_token FROM requests AS candidate
        WHERE candidate.status='pending'
          AND candidate.kind IN ('synchronize', 'discover')
          AND NOT EXISTS (
            SELECT 1 FROM claims WHERE claims.key_hash=candidate.key_hash
          )
          AND NOT EXISTS (
            SELECT 1 FROM requests AS earlier
            WHERE earlier.key_hash=candidate.key_hash
              AND earlier.status='pending'
              AND (CASE earlier.priority WHEN 'foreground' THEN 0 ELSE 1 END,
                   earlier.requested_at, earlier.rowid) <
                  (CASE candidate.priority WHEN 'foreground' THEN 0 ELSE 1 END,
                   candidate.requested_at, candidate.rowid)
          )
        ORDER BY CASE candidate.priority WHEN 'foreground' THEN 0 ELSE 1 END,
          candidate.requested_at, candidate.rowid LIMIT 1
      '''
            : "SELECT request_token FROM requests WHERE key_hash=? AND status='pending' ORDER BY CASE priority WHEN 'foreground' THEN 0 ELSE 1 END, requested_at, rowid LIMIT 1",
        global ? const [] : [hash],
      );
      admitted = rows.isNotEmpty && rows.single['request_token'] == request;
      if (global && !admitted && rows.isEmpty) {
        // A claim left by a dead worker must not make its key permanently
        // ineligible. The physical key mutex below is the liveness check.
        final staleClaimHead = db.select(
          "SELECT request_token FROM requests WHERE key_hash=? AND status='pending' ORDER BY CASE priority WHEN 'foreground' THEN 0 ELSE 1 END, requested_at, rowid LIMIT 1",
          [hash],
        );
        admitted =
            staleClaimHead.isNotEmpty &&
            staleClaimHead.single['request_token'] == request;
      }
      db.execute('COMMIT');
    } catch (_) {
      try {
        db.execute('ROLLBACK');
      } catch (_) {}
      rethrow;
    }
  });
  return admitted;
}

WalletSourceClaim _activate(
  String path,
  int busy,
  String hash,
  String request,
  String kind,
  String priority,
  bool allowRetired,
) {
  late WalletSourceClaim claim;
  _central(path, busy, (db) {
    db.execute('BEGIN IMMEDIATE');
    try {
      // The key mutex is held: a request queued since then waits for this
      // one even if it sorts first. Only a request removed meanwhile fails.
      final own = db.select(
        "SELECT 1 FROM requests WHERE request_token=? AND status='pending'",
        [request],
      );
      if (own.isEmpty) {
        _restoreRequest(db, (
          hash: hash,
          kind: kind,
          priority: priority,
          requestedAt: _now(),
        ), request);
      }
      final retired = db.select(
        'SELECT retired FROM source_state WHERE key_hash=?',
        [hash],
      );
      if (retired.isNotEmpty &&
          retired.single['retired'] == 1 &&
          !allowRetired) {
        throw StateError('wallet source is retired');
      }
      final old = db.select(
        'SELECT generation FROM generations WHERE key_hash=?',
        [hash],
      );
      final generation =
          (old.isEmpty ? 0 : old.single['generation'] as int) + 1;
      final token = _token();
      db.execute('INSERT OR REPLACE INTO generations VALUES (?,?)', [
        hash,
        generation,
      ]);
      db.execute('INSERT OR REPLACE INTO claims VALUES (?,?,?,?,?,?)', [
        hash,
        generation,
        token,
        kind,
        priority,
        _now(),
      ]);
      db.execute("DELETE FROM requests WHERE key_hash=? AND status='active'", [
        hash,
      ]);
      db.execute("UPDATE requests SET status='active' WHERE request_token=?", [
        request,
      ]);
      db.execute('COMMIT');
      claim = WalletSourceClaim(
        key: hash,
        generation: generation,
        ownerToken: token,
        kind: WalletOperationKind.values.byName(kind),
        priority: WalletOperationPriority.values.byName(priority),
      );
    } catch (_) {
      try {
        db.execute('ROLLBACK');
      } catch (_) {}
      rethrow;
    }
  });
  return claim;
}

void _central(String path, int busy, void Function(Database) action) {
  for (var attempt = 0; attempt < 20; attempt++) {
    final db = sqlite3.open(path);
    try {
      db.execute('PRAGMA busy_timeout = $busy');
      action(db);
      return;
    } catch (error) {
      if (!_isRetryable(error) || attempt == 19) rethrow;
      sleep(const Duration(milliseconds: 20));
    } finally {
      db.dispose();
    }
  }
}

bool _isRetryable(Object error) =>
    error is SqliteException &&
    (error.resultCode == SqlError.SQLITE_BUSY ||
        error.resultCode == SqlError.SQLITE_LOCKED);

int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;
String _token() => base64UrlEncode(
  List<int>.generate(16, (_) => Random.secure().nextInt(256)),
);
