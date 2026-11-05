import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:drift/drift.dart' show Value;
import 'package:wallet/wallet.dart';

class SqliteWalletCatalog implements WalletCatalogPort {
  final SqliteDatabase _sqlite;

  SqliteWalletCatalog({required this._sqlite});

  @override
  Future<void> store(WalletMetadata metadata) async {
    final companion = metadata.toSqlite();
    await _sqlite
        .into(_sqlite.walletMetadatas)
        .insertOnConflictUpdate(companion);
  }

  @override
  Future<WalletMetadata?> fetch(String walletId) async {
    final row = await _sqlite.managers.walletMetadatas
        .filter((e) => e.id(walletId))
        .getSingleOrNull();

    if (row == null) return null;
    return WalletMetadataMapper.fromSqlite(row);
  }

  @override
  Future<List<WalletMetadata>> fetchAll() async {
    final rows = await _sqlite.managers.walletMetadatas.get();
    return rows.map((e) => WalletMetadataMapper.fromSqlite(e)).toList();
  }

  @override
  Future<void> delete(String walletId) async {
    await _sqlite.managers.walletMetadatas
        .filter((e) => e.id(walletId))
        .delete();
  }
}

extension WalletMetadataMapper on WalletMetadata {
  WalletMetadatasCompanion toSqlite() => WalletMetadatasCompanion(
    id: Value(id),
    masterFingerprint: Value(masterFingerprint),
    xpubFingerprint: Value(xpubFingerprint),
    isEncryptedVaultTested: Value(isEncryptedVaultTested),
    isPhysicalBackupTested: Value(isPhysicalBackupTested),
    latestEncryptedBackup: Value(latestEncryptedBackup),
    latestPhysicalBackup: Value(latestPhysicalBackup),
    xpub: Value(xpub),
    externalPublicDescriptor: Value(externalPublicDescriptor),
    internalPublicDescriptor: Value(internalPublicDescriptor),
    signer: Value(signer.name),
    isDefault: Value(isDefault),
    label: Value(label),
    syncedAt: Value(syncedAt),
    signerDevice: Value(switch (signerDevice) {
      final device? => SignerDevice.fromEntity(device),
      null => null,
    }),
    birthday: Value(birthday),
  );

  static WalletMetadata fromSqlite(WalletMetadataRow row) => WalletMetadata(
    id: row.id,
    masterFingerprint: row.masterFingerprint,
    xpubFingerprint: row.xpubFingerprint,
    isEncryptedVaultTested: row.isEncryptedVaultTested,
    isPhysicalBackupTested: row.isPhysicalBackupTested,
    latestEncryptedBackup: row.latestEncryptedBackup,
    latestPhysicalBackup: row.latestPhysicalBackup,
    xpub: row.xpub,
    externalPublicDescriptor: row.externalPublicDescriptor,
    internalPublicDescriptor: row.internalPublicDescriptor,
    signer: Signer.fromName(row.signer).toEntity(),
    isDefault: row.isDefault,
    label: row.label,
    syncedAt: row.syncedAt,
    signerDevice: row.signerDevice?.toEntity(),
    birthday: row.birthday,
  );
}
