import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../domain/entities/wallet_sync_receipt.dart';
import '../domain/ports/wallet_sync_metadata_port.dart';
import '../domain/wallet_network_key.dart';
import '../domain/wallet_source_configuration.dart';
import '../domain/wallet_source_registration.dart';
import '../wallet_source_key_hash.dart';

/// Durable, package-owned storage for wallet source identity and sync metadata.
final class SqliteWalletSyncMetadataStore implements WalletSyncMetadataPort {
  static const _schemaVersion = 1;
  final Database _database;

  SqliteWalletSyncMetadataStore({
    required String databasePath,
    Duration busyTimeout = const Duration(milliseconds: 250),
  }) : _database = _open(databasePath, busyTimeout);

  static Database _open(String path, Duration busyTimeout) {
    Directory(File(path).parent.path).createSync(recursive: true);
    final database = sqlite3.open(path);
    try {
      database.execute('PRAGMA busy_timeout = ${busyTimeout.inMilliseconds}');
      database.execute('PRAGMA journal_mode = WAL');
      final version =
          database.select('PRAGMA user_version').single['user_version'] as int;
      if (version > _schemaVersion) {
        throw StateError('Unsupported wallet sync metadata schema');
      }
      database.execute('BEGIN IMMEDIATE');
      try {
        database.execute('''CREATE TABLE IF NOT EXISTS wallet_sync_metadata (
          key_hash TEXT PRIMARY KEY, source_kind TEXT NOT NULL, configuration_fingerprint TEXT NOT NULL,
          last_attempted_at INTEGER, last_successful_at INTEGER, content_fingerprint TEXT,
          deletion_pending INTEGER NOT NULL DEFAULT 0, deletion_phase TEXT)''');
        database.execute(
          '''CREATE TABLE IF NOT EXISTS wallet_sync_receipts (
          key_hash TEXT PRIMARY KEY, successful_at INTEGER NOT NULL, content_fingerprint TEXT NOT NULL,
          FOREIGN KEY (key_hash) REFERENCES wallet_sync_metadata(key_hash) ON DELETE CASCADE)''',
        );
        database.execute('PRAGMA user_version = 1');
        database.execute('COMMIT');
      } catch (_) {
        database.execute('ROLLBACK');
        rethrow;
      }
      return database;
    } catch (_) {
      database.dispose();
      rethrow;
    }
  }

  /// Closes the database after callers have checkpointed it if they inspect the file.
  void close() {
    _database.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    _database.dispose();
  }

  @override
  Future<WalletSyncMetadata?> read(WalletNetworkKey key) async {
    final rows = _database.select(
      'SELECT * FROM wallet_sync_metadata WHERE key_hash=?',
      [walletSourceKeyHash(key)],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return WalletSyncMetadata(
      registration: WalletSourceRegistration(
        key: key,
        sourceKind: row['source_kind'] as String,
        configurationFingerprint: row['configuration_fingerprint'] as String,
        configuration: const OpaqueSourceConfiguration('persisted'),
      ),
      lastAttemptedSyncAt: _date(row['last_attempted_at']),
      lastSuccessfulSyncAt: _date(row['last_successful_at']),
      contentFingerprint: row['content_fingerprint'] as String?,
      deletionPending: (row['deletion_pending'] as int) != 0,
      deletionPhase: _phase(row['deletion_phase'] as String?),
    );
  }

  @override
  Future<void> writeRegistration(WalletSourceRegistration registration) async {
    _database.execute(
      'INSERT OR IGNORE INTO wallet_sync_metadata (key_hash, source_kind, configuration_fingerprint) VALUES (?,?,?)',
      [
        walletSourceKeyHash(registration.key),
        registration.sourceKind,
        registration.configurationFingerprint,
      ],
    );
  }

  @override
  Future<void> writeAttempt(WalletNetworkKey key, DateTime at) async => _update(
    'UPDATE wallet_sync_metadata SET last_attempted_at=? WHERE key_hash=?',
    [at.toUtc().millisecondsSinceEpoch, walletSourceKeyHash(key)],
  );

  @override
  Future<void> writeSuccess(
    WalletNetworkKey key,
    DateTime at,
    String fingerprint,
  ) async => _update(
    'UPDATE wallet_sync_metadata SET last_successful_at=?, content_fingerprint=? WHERE key_hash=?',
    [at.toUtc().millisecondsSinceEpoch, fingerprint, walletSourceKeyHash(key)],
  );

  @override
  Future<WalletSyncReceipt?> readReceipt(WalletNetworkKey key) async {
    final rows = _database.select(
      'SELECT successful_at, content_fingerprint FROM wallet_sync_receipts WHERE key_hash=?',
      [walletSourceKeyHash(key)],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return WalletSyncReceipt(
      key: key,
      successfulAt: _date(row['successful_at'])!,
      contentFingerprint: row['content_fingerprint'] as String,
    );
  }

  @override
  Future<void> writeReceipt(WalletSyncReceipt receipt) async {
    final hash = walletSourceKeyHash(receipt.key);
    _database.execute(
      'INSERT OR REPLACE INTO wallet_sync_receipts (key_hash, successful_at, content_fingerprint) SELECT ?,?,? WHERE EXISTS (SELECT 1 FROM wallet_sync_metadata WHERE key_hash=?)',
      [
        hash,
        receipt.successfulAt.toUtc().millisecondsSinceEpoch,
        receipt.contentFingerprint,
        hash,
      ],
    );
    if (_database.updatedRows != 1) throw const _MetadataStorageException();
  }

  @override
  Future<void> writeDeletionMarker(
    WalletNetworkKey key,
    WalletDeletionPhase phase,
  ) async => _update(
    'UPDATE wallet_sync_metadata SET deletion_pending=1, deletion_phase=? WHERE key_hash=?',
    [phase.name, walletSourceKeyHash(key)],
  );

  @override
  Future<void> clear(WalletNetworkKey key) async {
    _database.execute('BEGIN');
    try {
      final hash = walletSourceKeyHash(key);
      _database.execute('DELETE FROM wallet_sync_receipts WHERE key_hash=?', [
        hash,
      ]);
      _database.execute('DELETE FROM wallet_sync_metadata WHERE key_hash=?', [
        hash,
      ]);
      _database.execute('COMMIT');
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  void _update(String sql, List<Object?> args) {
    _database.execute(sql, args);
    if (_database.updatedRows != 1) throw const _MetadataStorageException();
  }

  DateTime? _date(Object? value) => value == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(value as int, isUtc: true);
  WalletDeletionPhase? _phase(String? value) =>
      value == null ? null : WalletDeletionPhase.values.byName(value);
}

final class _MetadataStorageException implements Exception {
  const _MetadataStorageException();
}
