import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';
import 'package:meta/meta.dart';

import '../domain/entities/wallet_sync_receipt.dart';
import '../domain/ports/wallet_sync_metadata_port.dart';
import '../domain/wallet_network_key.dart';
import '../domain/wallet_source_configuration.dart';
import '../domain/wallet_source_registration.dart';
import '../wallet_source_key_hash.dart';
import '../wallet_source_operation_coordinator.dart';
import '../durable_wallet_source_operation_coordinator.dart';

const _metadataGate = WalletSourceKey(
  '__wallet_sync_metadata__',
  'sqlite',
  'v2',
);
const _metadataTestZoneKey = 'wallet_transaction_sync.metadata_test_config';

/// Durable metadata storage. Its SQLite connection never exists in the caller isolate.
final class SqliteWalletSyncMetadataStore implements WalletSyncMetadataPort {
  final _MetadataActor _actor;
  final DurableWalletSourceOperationCoordinator _coordinator;
  bool _closed = false;
  Future<void>? _closeFuture;

  SqliteWalletSyncMetadataStore._(this._actor, this._coordinator);

  static Future<SqliteWalletSyncMetadataStore> open({
    required String databasePath,
    Duration busyTimeout = const Duration(milliseconds: 250),
  }) async {
    return _open(databasePath: databasePath, busyTimeout: busyTimeout);
  }

  static Future<SqliteWalletSyncMetadataStore> _open({
    required String databasePath,
    required Duration busyTimeout,
  }) async {
    var testConfig = const <String, Object?>{};
    assert(() {
      final zoneConfig = Zone.current[_metadataTestZoneKey];
      if (zoneConfig is Map) {
        testConfig = zoneConfig.cast<String, Object?>();
      }
      return true;
    }());
    final actor = await _MetadataActor.start(
      commandDelay:
          testConfig['actorCommandDelay'] as Duration? ?? Duration.zero,
      killOnCommand: testConfig['killActorOnCommand'] as String?,
      failAfterObservationUpdate:
          testConfig['failAfterObservationUpdate'] as bool? ?? false,
      failCheckpoint: testConfig['failCheckpoint'] as bool? ?? false,
      gateHoldCommand: testConfig['gateHoldCommand'] as String?,
      gateHeldFile: testConfig['gateHeldFile'] as String?,
      gateReleaseFile: testConfig['gateReleaseFile'] as String?,
    );
    final store = SqliteWalletSyncMetadataStore._(
      actor,
      DurableWalletSourceOperationCoordinator(
        databasePath: '$databasePath.coordination.sqlite',
        busyTimeout: busyTimeout,
        acquisitionTimeout:
            testConfig['coordinationAcquisitionTimeout'] as Duration? ??
            const Duration(seconds: 30),
      ),
    );
    try {
      await store._mutate('open_schema', [
        databasePath,
        busyTimeout.inMilliseconds,
      ]);
      return store;
    } catch (_) {
      await store._actor.finish();
      rethrow;
    }
  }

  Future<T> _mutate<T>(String command, List<Object?> args) async {
    if (_closed) throw const _MetadataStorageException();
    try {
      return await _coordinator.runExclusive<T>(
        _metadataGate,
        (_) => _actor.command<T>(command, args),
        kind: WalletOperationKind.refresh,
        priority: WalletOperationPriority.background,
      );
    } on TimeoutException {
      throw const MetadataCoordinationTimeout();
    } on _MetadataStorageException {
      rethrow;
    } catch (_) {
      throw const _MetadataStorageException();
    }
  }

  @override
  Future<WalletSyncMetadata?> read(WalletNetworkKey key) async {
    final row = await _mutate<List<Object?>>('read', [
      walletSourceKeyHash(key),
    ]);
    if (row.isEmpty) return null;
    return _metadata(key, row);
  }

  @override
  Future<void> writeRegistration(WalletSourceRegistration registration) async {
    await _mutate('registration', [
      walletSourceKeyHash(registration.key),
      registration.sourceKind,
      registration.configurationFingerprint,
    ]);
  }

  @override
  Future<void> writeAttempt(WalletNetworkKey key, DateTime at) => _mutate(
    'attempt',
    [walletSourceKeyHash(key), at.toUtc().millisecondsSinceEpoch],
  );

  @override
  Future<void> recordLegacyForegroundSuccess(
    WalletNetworkKey key,
    DateTime at,
  ) async {
    await _mutate('legacy_success', [
      walletSourceKeyHash(key),
      at.toUtc().millisecondsSinceEpoch,
    ]);
  }

  @override
  Future<void> writeSuccessfulObservation(WalletSyncReceipt receipt) =>
      _mutate('observation', [
        walletSourceKeyHash(receipt.key),
        receipt.successfulAt.toUtc().millisecondsSinceEpoch,
        receipt.contentFingerprint,
      ]);

  @override
  Future<DateTime?> readLastSuccessfulSyncAt(WalletNetworkKey key) async {
    final value = await _mutate<Object?>('last_success', [
      walletSourceKeyHash(key),
    ]);
    return _date(value);
  }

  @override
  Future<WalletSyncReceipt?> readReceipt(WalletNetworkKey key) async {
    final row = await _mutate<List<Object?>>('receipt', [
      walletSourceKeyHash(key),
    ]);
    if (row.isEmpty) return null;
    return WalletSyncReceipt(
      key: key,
      successfulAt: _date(row[0])!,
      contentFingerprint: row[1] as String,
    );
  }

  @override
  Future<void> writeDeletionMarker(
    WalletNetworkKey key,
    WalletDeletionPhase phase,
  ) => _mutate('deletion', [walletSourceKeyHash(key), phase.name]);

  @override
  Future<void> clear(WalletNetworkKey key) =>
      _mutate('clear', [walletSourceKeyHash(key)]);

  Future<void> close() async {
    final existing = _closeFuture;
    if (existing != null) return existing;
    _closed = true;
    final closing = () async {
      Object? failure;
      try {
        await _coordinator.runExclusive<void>(
          _metadataGate,
          (_) => _actor.command<void>('terminate', const []),
          kind: WalletOperationKind.refresh,
          priority: WalletOperationPriority.background,
        );
      } catch (error) {
        failure = error;
      } finally {
        await _actor.finish();
      }
      if (failure != null) throw failure;
    }();
    _closeFuture = closing;
    return closing;
  }

  @visibleForTesting
  bool get actorExitObserved => _actor.actorExitObserved;

  WalletSyncMetadata _metadata(WalletNetworkKey key, List<Object?> r) =>
      WalletSyncMetadata(
        registration: WalletSourceRegistration(
          key: key,
          sourceKind: r[0] as String,
          configurationFingerprint: r[1] as String,
          configuration: const OpaqueSourceConfiguration('persisted'),
        ),
        lastAttemptedSyncAt: _date(r[2]),
        lastSuccessfulSyncAt: _date(r[3]),
        contentFingerprint: r[4] as String?,
        deletionPending: r[5] == 1,
        deletionPhase: r[6] == null
            ? null
            : WalletDeletionPhase.values.byName(r[6] as String),
      );
}

DateTime? _date(Object? value) => value == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(value as int, isUtc: true);

final class MetadataCoordinationTimeout implements Exception {
  const MetadataCoordinationTimeout();
  @override
  String toString() => 'Metadata coordination timed out';
}

final class _MetadataStorageException implements Exception {
  const _MetadataStorageException();
}

final class _MetadataActor {
  final SendPort _port;
  final ReceivePort _receive;
  final Stream<Object?> _messages;
  final Isolate _isolate;
  final ReceivePort _exit;
  final ReceivePort _errors;
  int _next = 0;
  final _pending = <int, Completer<Object?>>{};
  bool _closed = false;
  bool _terminated = false;
  Object? _terminalError;
  _MetadataActor(
    this._port,
    this._receive,
    this._isolate,
    this._messages,
    this._exit,
    this._errors,
  ) {
    _messages.listen((message) {
      if (message is! List || message.length < 3) return;
      final c = _pending.remove(message[0]);
      if (c == null) return;
      if (message[1] == true) {
        c.complete(message[2]);
      } else {
        c.completeError(_MetadataStorageException());
      }
    });
    _exit.listen((_) => _observeExit());
    _errors.listen((_) => _markTerminal(const _MetadataStorageException()));
  }
  static Future<_MetadataActor> start({
    Duration commandDelay = Duration.zero,
    String? killOnCommand,
    bool failAfterObservationUpdate = false,
    bool failCheckpoint = false,
    String? gateHoldCommand,
    String? gateHeldFile,
    String? gateReleaseFile,
  }) async {
    final receive = ReceivePort();
    final messages = receive.asBroadcastStream();
    final exit = ReceivePort();
    final errors = ReceivePort();
    final ready = Completer<SendPort>();
    final isolate = await Isolate.spawn(_metadataMain, [
      receive.sendPort,
      commandDelay.inMilliseconds,
      killOnCommand,
      failAfterObservationUpdate,
      failCheckpoint,
      gateHoldCommand,
      gateHeldFile,
      gateReleaseFile,
    ]);
    isolate.addOnExitListener(exit.sendPort);
    isolate.addErrorListener(errors.sendPort);
    final sub = messages.listen((m) {
      if (m is SendPort && !ready.isCompleted) ready.complete(m);
    });
    try {
      final port = await ready.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw const MetadataCoordinationTimeout(),
      );
      await sub.cancel();
      return _MetadataActor(port, receive, isolate, messages, exit, errors);
    } catch (_) {
      await sub.cancel();
      receive.close();
      exit.close();
      errors.close();
      isolate.kill(priority: Isolate.immediate);
      rethrow;
    }
  }

  Future<T> command<T>(String command, List<Object?> args) {
    if (_closed) {
      return Future.error(_terminalError ?? const _MetadataStorageException());
    }
    final id = ++_next;
    final c = Completer<Object?>();
    _pending[id] = c;
    if (command == 'terminate') _terminated = true;
    _port.send([id, command, args]);
    return c.future
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            _pending.remove(id);
            throw const MetadataCoordinationTimeout();
          },
        )
        .then((v) => v as T);
  }

  Future<void> finish() async {
    if (_exitObserved) return;
    try {
      if (!_terminated && !_closed) {
        await command<void>('terminate', const []);
      }
    } finally {
      _markTerminal(_terminalError ?? const _MetadataStorageException());
      try {
        await _exitFuture.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        _isolate.kill(priority: Isolate.immediate);
        await _exitFuture.timeout(const Duration(seconds: 2));
      }
      _closePorts();
    }
  }

  bool _exitObserved = false;
  late final Future<void> _exitFuture = _exitCompleter.future;
  final _exitCompleter = Completer<void>();

  void _observeExit() {
    if (_exitObserved) return;
    _exitObserved = true;
    if (!_exitCompleter.isCompleted) _exitCompleter.complete();
    _markTerminal(const _MetadataStorageException());
    _closePorts();
  }

  void _closePorts() {
    _receive.close();
    _exit.close();
    _errors.close();
  }

  @visibleForTesting
  bool get actorExitObserved => _exitObserved;

  void _markTerminal(Object error) {
    if (_closed) return;
    _closed = true;
    _terminalError = error;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
  }
}

void _metadataMain(List<Object?> args) {
  final out = args[0] as SendPort;
  final commandDelay = Duration(milliseconds: args[1] as int);
  final killOnCommand = args[2] as String?;
  final failAfterObservationUpdate = args[3] as bool;
  final failCheckpoint = args[4] as bool;
  final gateHoldCommand = args[5] as String?;
  final gateHeldFile = args[6] as String?;
  final gateReleaseFile = args[7] as String?;
  final commands = ReceivePort();
  Database? db;
  var gateWasHeld = false;
  out.send(commands.sendPort);
  commands.listen((message) {
    final id = message[0] as int;
    final command = message[1] as String;
    final a = (message[2] as List).cast<Object?>();
    if (commandDelay > Duration.zero) sleep(commandDelay);
    if (command == killOnCommand) {
      Isolate.current.kill(priority: Isolate.immediate);
      return;
    }
    if (!gateWasHeld && command == gateHoldCommand && gateHeldFile != null) {
      gateWasHeld = true;
      final marker = File(gateHeldFile)..createSync(exclusive: true);
      marker.writeAsStringSync(
        DateTime.now().microsecondsSinceEpoch.toString(),
      );
      while (gateReleaseFile == null || !File(gateReleaseFile).existsSync()) {
        sleep(const Duration(milliseconds: 5));
      }
    }
    try {
      Object? result;
      if (command == 'open_schema') {
        final path = a[0] as String;
        final busy = a[1] as int;
        Directory(File(path).parent.path).createSync(recursive: true);
        db = sqlite3.open(path);
        db!.execute('PRAGMA busy_timeout = $busy');
        db!.execute('PRAGMA journal_mode = WAL');
        _metadataCommand(db!, 'schema', const []);
      } else if (db == null) {
        throw StateError('metadata actor is not open');
      } else if (command == 'terminate') {
        if (failCheckpoint) throw const _MetadataStorageException();
        db!.execute('PRAGMA wal_checkpoint(TRUNCATE)');
        db!.dispose();
        db = null;
      } else {
        result = _metadataCommand(
          db!,
          command,
          a,
          failAfterObservationUpdate: failAfterObservationUpdate,
          failCheckpoint: failCheckpoint,
        );
      }
      if (command == 'terminate') {
        out.send([id, true, result]);
        commands.close();
      } else {
        out.send([id, true, result]);
      }
    } catch (_) {
      if (command == 'terminate') {
        try {
          db?.dispose();
        } catch (_) {}
        db = null;
        commands.close();
      }
      out.send([id, false, null]);
    }
  });
}

Object? _metadataCommand(
  Database db,
  String command,
  List<Object?> a, {
  bool failAfterObservationUpdate = false,
  bool failCheckpoint = false,
}) {
  if (command == 'schema') {
    db.execute('BEGIN IMMEDIATE');
    try {
      final version =
          db.select('PRAGMA user_version').single['user_version'] as int;
      if (version > 2) throw StateError('future schema');
      db.execute(
        '''CREATE TABLE IF NOT EXISTS wallet_sync_metadata (key_hash TEXT PRIMARY KEY, source_kind TEXT NOT NULL, configuration_fingerprint TEXT NOT NULL, last_attempted_at INTEGER, last_successful_at INTEGER, content_fingerprint TEXT, deletion_pending INTEGER NOT NULL DEFAULT 0, deletion_phase TEXT)''',
      );
      db.execute(
        '''CREATE TABLE IF NOT EXISTS wallet_sync_receipts (key_hash TEXT PRIMARY KEY, successful_at INTEGER NOT NULL, content_fingerprint TEXT NOT NULL, FOREIGN KEY (key_hash) REFERENCES wallet_sync_metadata(key_hash) ON DELETE CASCADE)''',
      );
      db.execute(
        '''CREATE TABLE IF NOT EXISTS wallet_sync_pending_legacy_success (key_hash TEXT PRIMARY KEY, successful_at INTEGER NOT NULL)''',
      );
      db.execute('PRAGMA user_version = 2');
      db.execute('COMMIT');
      return null;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
  if (command == 'read') return _row(db, a[0]);
  if (command == 'receipt') {
    final r = db.select(
      'SELECT successful_at, content_fingerprint FROM wallet_sync_receipts WHERE key_hash=?',
      [a[0]],
    );
    return r.isEmpty
        ? const []
        : [r.single['successful_at'], r.single['content_fingerprint']];
  }
  if (command == 'last_success') {
    final canonical = db.select(
      'SELECT last_successful_at FROM wallet_sync_metadata WHERE key_hash=?',
      [a[0]],
    );
    final pending = db.select(
      'SELECT successful_at FROM wallet_sync_pending_legacy_success WHERE key_hash=?',
      [a[0]],
    );
    final values = <int>[
      if (canonical.isNotEmpty &&
          canonical.single['last_successful_at'] != null)
        canonical.single['last_successful_at'] as int,
      if (pending.isNotEmpty) pending.single['successful_at'] as int,
    ];
    return values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);
  }
  db.execute('BEGIN');
  try {
    switch (command) {
      case 'registration':
        db.execute(
          'INSERT OR IGNORE INTO wallet_sync_metadata (key_hash,source_kind,configuration_fingerprint) VALUES (?,?,?)',
          a,
        );
        db.execute(
          'UPDATE wallet_sync_metadata SET last_successful_at=CASE WHEN last_successful_at IS NULL OR last_successful_at < (SELECT successful_at FROM wallet_sync_pending_legacy_success WHERE key_hash=?) THEN (SELECT successful_at FROM wallet_sync_pending_legacy_success WHERE key_hash=?) ELSE last_successful_at END WHERE key_hash=? AND EXISTS (SELECT 1 FROM wallet_sync_pending_legacy_success WHERE key_hash=?)',
          [a[0], a[0], a[0], a[0]],
        );
        db.execute(
          'DELETE FROM wallet_sync_pending_legacy_success WHERE key_hash=?',
          [a[0]],
        );
      case 'attempt':
        _mustUpdate(
          db,
          'UPDATE wallet_sync_metadata SET last_attempted_at=? WHERE key_hash=?',
          [a[1], a[0]],
        );
      case 'legacy_success':
        final registered = db.select(
          'SELECT last_successful_at FROM wallet_sync_metadata WHERE key_hash=?',
          [a[0]],
        );
        if (registered.isNotEmpty) {
          db.execute(
            'UPDATE wallet_sync_metadata SET last_successful_at=CASE WHEN last_successful_at IS NULL OR last_successful_at < ? THEN ? ELSE last_successful_at END WHERE key_hash=?',
            [a[1], a[1], a[0]],
          );
          db.execute(
            'DELETE FROM wallet_sync_pending_legacy_success WHERE key_hash=?',
            [a[0]],
          );
        } else {
          final previous = db.select(
            'SELECT successful_at FROM wallet_sync_pending_legacy_success WHERE key_hash=?',
            [a[0]],
          );
          final timestamp = previous.isEmpty
              ? a[1] as int
              : ((previous.single['successful_at'] as int) > (a[1] as int)
                    ? previous.single['successful_at'] as int
                    : a[1] as int);
          db.execute(
            'INSERT OR REPLACE INTO wallet_sync_pending_legacy_success VALUES (?,?)',
            [a[0], timestamp],
          );
        }
      case 'observation':
        _mustUpdate(
          db,
          'UPDATE wallet_sync_metadata SET last_successful_at=?,content_fingerprint=? WHERE key_hash=?',
          [a[1], a[2], a[0]],
        );
        if (failAfterObservationUpdate) {
          throw const _MetadataStorageException();
        }
        _mustUpdate(
          db,
          'INSERT OR REPLACE INTO wallet_sync_receipts VALUES (?,?,?)',
          [a[0], a[1], a[2]],
        );
      case 'deletion':
        _mustUpdate(
          db,
          'UPDATE wallet_sync_metadata SET deletion_pending=1,deletion_phase=? WHERE key_hash=?',
          [a[1], a[0]],
        );
      case 'clear':
        db.execute('DELETE FROM wallet_sync_receipts WHERE key_hash=?', a);
        db.execute('DELETE FROM wallet_sync_metadata WHERE key_hash=?', a);
        db.execute(
          'DELETE FROM wallet_sync_pending_legacy_success WHERE key_hash=?',
          a,
        );
      case 'checkpoint':
        if (failCheckpoint) throw const _MetadataStorageException();
        db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    }
    db.execute('COMMIT');
    return null;
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

List<Object?> _row(Database db, Object? hash) {
  final r = db.select(
    'SELECT source_kind,configuration_fingerprint,last_attempted_at,last_successful_at,content_fingerprint,deletion_pending,deletion_phase FROM wallet_sync_metadata WHERE key_hash=?',
    [hash],
  );
  if (r.isEmpty) return const [];
  final x = r.single;
  return [
    x['source_kind'],
    x['configuration_fingerprint'],
    x['last_attempted_at'],
    x['last_successful_at'],
    x['content_fingerprint'],
    x['deletion_pending'],
    x['deletion_phase'],
  ];
}

void _mustUpdate(Database db, String sql, List<Object?> args) {
  db.execute(sql, args);
  if (db.updatedRows != 1) throw const _MetadataStorageException();
}
