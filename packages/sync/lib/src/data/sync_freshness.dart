import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:legacy_storage/wallet_column_projection.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart'
    show SecretsInventory, WalletPropertyDraft, WalletPropertyStore;
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../domain/sync_failure.dart';
import '../domain/wallet_key.dart';
import 'sync_freshness.drift.dart';

@DataClassName('WalletSyncTimeRow')
class WalletSyncTimes extends Table {
  TextColumn get walletId => text()();
  TextColumn get syncedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {walletId};
}

class LegacyImportReceipts extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [WalletSyncTimes, LegacyImportReceipts])
final class SyncFreshnessDatabase extends $SyncFreshnessDatabase {
  SyncFreshnessDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() => migrator.createAll()),
  );
}

LegacyImportParticipant syncWalletMetadataImport({
  required File file,
  required DatabaseKeys keys,
}) => _projection(file, keys);

WalletColumnProjection<SyncFreshnessDatabase> _projection(
  File file,
  DatabaseKeys keys,
) => WalletColumnProjection(
  ownerId: 'sync',
  file: file,
  column: 'synced_at',
  destinationTable: 'wallet_sync_times',
  create: SyncFreshnessDatabase.new,
  openExecutor: ({required existing}) async =>
      (await keys.open(
        name: 'main',
        file: file,
        existingSchemaVersion: existing ? 1 : null,
      )).mapErr(
        (failure) => switch (failure) {
          DatabaseNotReady() ||
          DatabaseKeyUnavailable(
            reason: DatabaseKeyProblem.locked,
          ) => const LegacyImportDeferred(),
          _ => const LegacyImportUnavailable(),
        },
      ),
);

final class SyncFreshness implements WalletPropertyStore {
  final SyncFreshnessDatabase _database;

  const SyncFreshness._(this._database);

  @useResult
  static Future<Result<SyncFreshness, SyncFailure>> open({
    required File file,
    required RuntimeAdmission admission,
    required DatabaseKeys keys,
  }) async =>
      (await _projection(file, keys).openRuntime(admission))
          .map(SyncFreshness._)
          .mapErr((_) => const SyncStorageFailure());

  /// A new wallet has never been synced.
  @override
  Future<Result<void, Failure>> prepareWallet(
    WalletPropertyDraft wallet,
  ) async => (await write(wallet.id, null)).mapErr((failure) => failure);

  /// Stamps each completed sync of a wallet the inventory still lists, so a
  /// sync finishing after a deletion never recreates its timestamp.
  StreamSubscription<WalletKey> recordCompletions(
    Stream<WalletKey> completed,
    SecretsInventory inventory,
  ) => completed.listen((key) async {
    switch (await inventory.findWallet(key.id)) {
      case Ok(value: null):
        return;
      case Ok():
        if (await write(key.id, DateTime.now()) case Err()) {
          log.warning('Wallet sync timestamp unavailable');
        }
      case Err():
        log.warning('Wallet sync timestamp unavailable');
    }
  });

  @useResult
  Future<Result<DateTime?, SyncFailure>> read(String walletId) async {
    try {
      final row = await (_database.select(
        _database.walletSyncTimes,
      )..where((row) => row.walletId.equals(walletId))).getSingleOrNull();
      final timestamp = row?.syncedAt;
      if (timestamp == null) return const Ok(null);
      final parsed = DateTime.tryParse(timestamp);
      return parsed == null ? const Err(SyncStorageFailure()) : Ok(parsed);
    } on SqliteException {
      return const Err(SyncStorageFailure());
    }
  }

  @useResult
  Future<Result<void, SyncFailure>> write(
    String walletId,
    DateTime? value,
  ) async {
    try {
      await _database
          .into(_database.walletSyncTimes)
          .insertOnConflictUpdate(
            WalletSyncTimesCompanion.insert(
              walletId: walletId,
              syncedAt: Value(value?.toIso8601String()),
            ),
          );
      return const Ok(null);
    } on SqliteException {
      return const Err(SyncStorageFailure());
    }
  }
}
