import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart';

import 'wallet_source_key_hash.dart';
import 'wallet_source_operation_coordinator.dart';
import 'wallet_source_session.dart';

final class DurableWalletSourceOperationCoordinator
    implements WalletSourceOperationCoordinator {
  final String databasePath;
  final String lockDirectoryPath;
  final Duration busyTimeout;
  final Duration pendingHeartbeatTimeout;
  final Duration? acquisitionTimeout;
  @visibleForTesting
  final void Function()? beforeClaimRelease;
  @visibleForTesting
  final Duration workerInitializationDelay;
  @visibleForTesting
  final bool failReleaseCleanup;
  @visibleForTesting
  final bool killWorkerAfterReady;

  DurableWalletSourceOperationCoordinator({
    required this.databasePath,
    String? lockDirectoryPath,
    this.busyTimeout = const Duration(milliseconds: 250),
    this.pendingHeartbeatTimeout = const Duration(seconds: 30),
    this.acquisitionTimeout = const Duration(seconds: 30),
    @visibleForTesting this.beforeClaimRelease,
    @visibleForTesting this.workerInitializationDelay = Duration.zero,
    @visibleForTesting this.failReleaseCleanup = false,
    @visibleForTesting this.killWorkerAfterReady = false,
  }) : lockDirectoryPath =
           lockDirectoryPath ??
           '${File(databasePath).parent.path}/wallet-source-locks';

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
    final keyHash = hashWalletSourceParts(
      sourceKey.walletId,
      sourceKey.chain,
      sourceKey.network,
    );
    final actor = await _DurableActor.start(
      databasePath: databasePath,
      lockDirectoryPath: lockDirectoryPath,
      busyTimeout: busyTimeout,
      pendingHeartbeatTimeout: pendingHeartbeatTimeout,
      acquisitionTimeout: acquisitionTimeout,
      keyHash: keyHash,
      kind: kind,
      priority: priority,
      allowRetired: allowRetired,
      workerInitializationDelay: workerInitializationDelay,
      failReleaseCleanup: failReleaseCleanup,
      killWorkerAfterReady: killWorkerAfterReady,
    );
    final session = _DurableSession(actor);
    Timer? timer;
    late T value;
    Object? operationError;
    StackTrace? operationStack;
    var finished = false;
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
      Object? cleanupError;
      try {
        beforeClaimRelease?.call();
      } catch (error) {
        cleanupError = error;
      }
      try {
        await session.close();
      } catch (error) {
        cleanupError ??= error;
      }
      if (finished && !result.isCompleted) {
        if (cleanupError != null) {
          result.completeError(cleanupError);
        } else if (operationError != null) {
          result.completeError(operationError, operationStack);
        } else {
          result.complete(value);
        }
      }
    }
  }
}

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
    if (_closed) throw StateError('source session is closed');
    // The actor holds the per-key BEGIN IMMEDIATE connection for this session.
    // Consequently this claim cannot be replaced until release is requested.
  }

  @override
  void retire() {
    ensureOpen();
    _commands.add(_actor.setRetired(true));
  }

  @override
  void reactivate() {
    ensureOpen();
    _commands.add(_actor.setRetired(false));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    Object? firstError;
    try {
      await Future.wait(_commands);
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

  _DurableActor(
    this._port,
    this._responses,
    this._receivePort,
    this._isolate,
    this._exitPort,
    this.claim,
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

  static Future<_DurableActor> start({
    required String databasePath,
    required String lockDirectoryPath,
    required Duration busyTimeout,
    required Duration pendingHeartbeatTimeout,
    required Duration? acquisitionTimeout,
    required String keyHash,
    required WalletOperationKind kind,
    required WalletOperationPriority priority,
    required bool allowRetired,
    required Duration workerInitializationDelay,
    required bool failReleaseCleanup,
    required bool killWorkerAfterReady,
  }) async {
    final registrationKey = '$databasePath\u0000$keyHash';
    final previousRegistration =
        _registrationTails[registrationKey] ?? Future<void>.value();
    final registered = Completer<void>();
    late final Future<void> registrationTail;
    registrationTail = registered.future.whenComplete(() {});
    _registrationTails[registrationKey] = registrationTail;
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
        keyHash,
        kind.name,
        priority.name,
        allowRetired,
        workerInitializationDelay.inMilliseconds,
        failReleaseCleanup,
        responses.sendPort,
        killWorkerAfterReady,
      ]);
    } catch (_) {
      responses.close();
      exitPort.close();
      handshakeExit.close();
      if (!registered.isCompleted) registered.complete();
      if (identical(_registrationTails[registrationKey], registrationTail)) {
        _registrationTails.remove(registrationKey);
      }
      rethrow;
    }
    isolate.addOnExitListener(exitPort.sendPort);
    isolate.addOnExitListener(handshakeExit.sendPort);
    late StreamSubscription<Object?> subscription;
    final handshakeExitSubscription = handshakeExit.listen((_) {
      if (!ready.isCompleted) {
        ready.completeError(
          StateError('Wallet source coordination worker exited'),
        );
      }
      if (!registered.isCompleted) registered.complete();
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
      if (!registered.isCompleted) registered.complete();
      if (identical(_registrationTails[registrationKey], registrationTail)) {
        _registrationTails.remove(registrationKey);
      }
      isolate.kill(priority: Isolate.immediate);
      rethrow;
    }
  }

  Future<void> setRetired(bool retired) =>
      _command('retire', retired).then((_) {});
  Future<void> release() async {
    if (_closed) {
      if (_terminalError != null) throw _terminalError!;
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
      _isolate.kill(priority: Isolate.immediate);
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
  final hash = args[6] as String;
  final initializationDelay = args[10] as int;
  final failReleaseCleanup = args[11] as bool;
  final killWorkerAfterReady = args[13] as bool;
  final request = _token();
  final commands = ReceivePort();
  ReceivePort? registrationReply;
  Database? mutex;
  WalletSourceClaim? claim;
  var readySent = false;
  var awaitingTermination = false;
  try {
    final reply = ReceivePort();
    registrationReply = reply;
    out.send(['register', reply.sendPort]);
    await reply.first;
    reply.close();
    registrationReply = null;
    Directory(File(dbPath).parent.path).createSync(recursive: true);
    Directory(lockPath).createSync(recursive: true);
    _initialize(dbPath, busy);
    _central(
      dbPath,
      busy,
      (db) => db.execute('INSERT INTO requests VALUES (?,?,?,?,?,?)', [
        request,
        hash,
        args[8],
        'pending',
        _now(),
        _now(),
      ]),
    );
    out.send(['registered']);
    if (initializationDelay > 0) {
      sleep(Duration(milliseconds: initializationDelay));
    }
    mutex = _acquire(dbPath, lockPath, hash, request, busy, stale, acquisition);
    claim = _activate(
      dbPath,
      busy,
      hash,
      request,
      args[7] as String,
      args[8] as String,
      args[9] as bool,
    );
    out.send(['ready', commands.sendPort, claim.generation, claim.ownerToken]);
    readySent = true;
    if (killWorkerAfterReady) {
      Isolate.current.kill(priority: Isolate.immediate);
      return;
    }
    await for (final message in commands) {
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
            _bestEffortCleanup(dbPath, busy, hash, request, claim, mutex);
            claim = null;
            mutex = null;
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
          _bestEffortCleanup(dbPath, busy, hash, request, claim, mutex);
          claim = null;
          mutex = null;
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
      out.send(['error', _category(error)]);
    }
  } finally {
    _bestEffortCleanup(dbPath, busy, hash, request, claim, mutex);
    registrationReply?.close();
    commands.close();
  }
}

void _bestEffortCleanup(
  String dbPath,
  int busy,
  String hash,
  String request,
  WalletSourceClaim? claim,
  Database? mutex,
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
  try {
    _central(
      dbPath,
      busy,
      (db) =>
          db.execute('DELETE FROM requests WHERE request_token=?', [request]),
    );
  } catch (_) {}
  if (mutex != null) {
    try {
      mutex.execute('ROLLBACK');
    } catch (_) {}
    try {
      mutex.dispose();
    } catch (_) {}
  }
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
  if (error is StateError) return 'state';
  final text = error.toString();
  if (text.contains('retired')) return 'retired';
  if (text.contains('superseded')) return 'superseded';
  if (text.contains('Unsupported')) return 'unsupported-schema';
  return 'coordination';
}

void _initialize(String path, int busy) => _central(path, busy, (db) {
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

Database _acquire(
  String central,
  String locks,
  String hash,
  String request,
  int busy,
  int stale,
  int? timeout,
) {
  final deadline = timeout == null
      ? null
      : DateTime.now().add(Duration(milliseconds: timeout));
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
    final admitted = _admit(central, busy, hash, request, stale);
    if (admitted) {
      final db = sqlite3.open('$locks/$hash.sqlite');
      db.execute('PRAGMA busy_timeout = $busy');
      try {
        db.execute('BEGIN IMMEDIATE');
        if (_admit(central, busy, hash, request, stale)) return db;
        db.execute('ROLLBACK');
        db.dispose();
      } catch (error) {
        db.dispose();
        if (error is! SqliteException ||
            (error.resultCode != SqlError.SQLITE_BUSY &&
                error.resultCode != SqlError.SQLITE_LOCKED)) {
          rethrow;
        }
      }
    }
    sleep(const Duration(milliseconds: 20));
  }
}

bool _admit(String path, int busy, String hash, String request, int stale) {
  var admitted = false;
  _central(path, busy, (db) {
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute(
        "UPDATE requests SET heartbeat_at=? WHERE request_token=? AND status='pending'",
        [_now(), request],
      );
      if (db.updatedRows != 1) {
        throw StateError('coordinator request superseded');
      }
      db.execute(
        "DELETE FROM requests WHERE key_hash=? AND status='pending' AND heartbeat_at < ? AND request_token <> ?",
        [hash, _now() - stale, request],
      );
      final rows = db.select(
        "SELECT request_token FROM requests WHERE key_hash=? AND status='pending' ORDER BY CASE priority WHEN 'foreground' THEN 0 ELSE 1 END, requested_at, rowid LIMIT 1",
        [hash],
      );
      admitted = rows.isNotEmpty && rows.single['request_token'] == request;
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
      final head = db.select(
        "SELECT request_token FROM requests WHERE key_hash=? AND status='pending' ORDER BY CASE priority WHEN 'foreground' THEN 0 ELSE 1 END, requested_at, rowid LIMIT 1",
        [hash],
      );
      if (head.isEmpty || head.single['request_token'] != request) {
        throw StateError('coordinator request superseded');
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
