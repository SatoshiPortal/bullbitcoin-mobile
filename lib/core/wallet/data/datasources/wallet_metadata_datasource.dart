import 'package:drift/drift.dart';
import 'package:transaction_sync/transaction_sync.dart' show BitcoinSyncSource;
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';

class WalletMetadataDatasource {
  final SqliteDatabase _sqlite;

  WalletMetadataDatasource({required this._sqlite});

  Future<void> store(WalletMetadataModel metadata) async {
    final companion = metadata.toSqlite();
    await _sqlite
        .into(_sqlite.walletMetadatas)
        .insert(
          companion,
          // Preferences change only through the serialized, column-scoped
          // setter. A delayed backup save must not restore an old transport.
          onConflict: DoUpdate(
            (_) => companion.copyWith(
              bitcoinSyncSource: const Value.absent(),
              birthday: const Value.absent(),
            ),
          ),
        );
  }

  Future<bool> updateBitcoinSyncSource(
    String walletId,
    BitcoinSyncSource source,
  ) async {
    final changed =
        await (_sqlite.update(
          _sqlite.walletMetadatas,
        )..where((row) => row.id.equals(walletId))).write(
          WalletMetadatasCompanion(bitcoinSyncSource: Value(source.name)),
        );
    return changed == 1;
  }

  Future<bool> updateBitcoinSyncSettings(
    String walletId,
    BitcoinSyncSource source,
    DateTime? birthday,
  ) async {
    final changed =
        await (_sqlite.update(
          _sqlite.walletMetadatas,
        )..where((row) => row.id.equals(walletId))).write(
          WalletMetadatasCompanion(
            bitcoinSyncSource: Value(source.name),
            birthday: Value(birthday),
          ),
        );
    return changed == 1;
  }

  Future<WalletMetadataModel?> fetch(String walletId) async {
    final row = await _sqlite.managers.walletMetadatas
        .filter((e) => e.id(walletId))
        .getSingleOrNull();

    if (row == null) return null;
    return WalletMetadataModelMapper.fromSqlite(row);
  }

  /// Only wallet-list presentation may omit an unavailable policy. Privacy guards use the strict default so an omitted wallet cannot authorize anonymous Electrum access.
  Future<List<WalletMetadataModel>> fetchAll({
    bool skipUnavailableSources = false,
  }) async {
    final rows = await _sqlite.managers.walletMetadatas.get();
    final wallets = <WalletMetadataModel>[];
    for (final row in rows) {
      try {
        wallets.add(WalletMetadataModelMapper.fromSqlite(row));
      } on UnknownBitcoinSyncSourceException {
        if (!skipUnavailableSources) rethrow;
      }
    }
    return wallets;
  }

  Stream<List<WalletMetadataModel>> watchSyncPolicies() =>
      _sqlite.managers.walletMetadatas.watch().map((rows) {
        final wallets = <WalletMetadataModel>[];
        for (final row in rows) {
          try {
            wallets.add(WalletMetadataModelMapper.fromSqlite(row));
          } on UnknownBitcoinSyncSourceException {
            /* An unavailable row cannot stop healthy nodes. */
          }
        }
        return wallets;
      });

  Future<void> delete(String walletId) async {
    await _sqlite.managers.walletMetadatas
        .filter((e) => e.id(walletId))
        .delete();
  }
}
