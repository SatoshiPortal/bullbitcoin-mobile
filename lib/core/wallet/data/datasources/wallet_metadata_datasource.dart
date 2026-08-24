import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_metadata_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:drift/drift.dart';

class WalletMetadataDatasource {
  final SqliteDatabase _sqlite;

  WalletMetadataDatasource({required this._sqlite});

  Future<void> store(WalletMetadataModel metadata) async {
    await _sqlite.transaction(() async {
      await _sqlite
          .into(_sqlite.walletMetadatas)
          .insertOnConflictUpdate(metadata.toSqlite());
      await (_sqlite.delete(
        _sqlite.walletSigners,
      )..where((row) => row.walletId.equals(metadata.id))).go();
      final signers = metadata.signersToSqlite();
      if (signers.isNotEmpty) {
        await _sqlite.batch(
          (batch) => batch.insertAll(_sqlite.walletSigners, signers),
        );
      }
      final descriptorKeys = metadata.descriptorKeysToSqlite();
      if (descriptorKeys.isNotEmpty) {
        await _sqlite.batch(
          (batch) =>
              batch.insertAll(_sqlite.walletDescriptorKeys, descriptorKeys),
        );
      }
    });
  }

  Future<WalletMetadataModel?> fetch(String walletId) =>
      _sqlite.transaction(() async {
        final row = await _sqlite.managers.walletMetadatas
            .filter((e) => e.id(walletId))
            .getSingleOrNull();

        if (row == null) return null;
        final signerRows = await _fetchSigners(walletId);
        final descriptorKeyRows = await _fetchDescriptorKeys(walletId);
        return WalletMetadataMapper.fromSqlite(
          row,
          signerRows,
          descriptorKeyRows,
        );
      });

  Future<List<WalletMetadataModel>> fetchAll() => _sqlite.transaction(() async {
    final rows = await _sqlite.managers.walletMetadatas.get();
    final signers = await _sqlite.managers.walletSigners.get();
    final descriptorKeys = await _sqlite.managers.walletDescriptorKeys.get();
    final signersByWallet = <String, List<WalletSignerRow>>{};
    final keysByWallet = <String, List<WalletDescriptorKeyRow>>{};
    for (final signer in signers) {
      signersByWallet.putIfAbsent(signer.walletId, () => []).add(signer);
    }
    for (final key in descriptorKeys) {
      keysByWallet.putIfAbsent(key.walletId, () => []).add(key);
    }
    return [
      for (final row in rows)
        WalletMetadataMapper.fromSqlite(
          row,
          signersByWallet[row.id] ?? const [],
          keysByWallet[row.id] ?? const [],
        ),
    ];
  });

  Future<void> delete(String walletId) async {
    await _sqlite.managers.walletMetadatas
        .filter((row) => row.id(walletId))
        .delete();
  }

  Future<bool> updateSignerDevice({
    required String walletId,
    required String signerId,
    required Signer signer,
    required SignerDevice? signerDevice,
  }) async {
    final updatedRows =
        await (_sqlite.update(_sqlite.walletSigners)..where(
              (row) => row.walletId.equals(walletId) & row.id.equals(signerId),
            ))
            .write(
              WalletSignersCompanion(
                signer: Value(signer),
                signerDevice: Value(signerDevice),
              ),
            );
    return updatedRows == 1;
  }

  Future<bool> updateSyncedAt({
    required String walletId,
    required DateTime syncedAt,
  }) async {
    final updatedRows =
        await (_sqlite.update(_sqlite.walletMetadatas)
              ..where((row) => row.id.equals(walletId)))
            .write(WalletMetadatasCompanion(syncedAt: Value(syncedAt)));
    return updatedRows == 1;
  }

  Future<List<WalletSignerRow>> _fetchSigners(String walletId) async {
    final query = _sqlite.select(_sqlite.walletSigners)
      ..where((row) => row.walletId.equals(walletId))
      ..orderBy([(row) => OrderingTerm.asc(row.position)]);
    return query.get();
  }

  Future<List<WalletDescriptorKeyRow>> _fetchDescriptorKeys(
    String walletId,
  ) async {
    final query = _sqlite.select(_sqlite.walletDescriptorKeys)
      ..where((row) => row.walletId.equals(walletId))
      ..orderBy([(row) => OrderingTerm.asc(row.position)]);
    return query.get();
  }
}
