import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/v5_migrate_wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'new_wallet_metadata_model.freezed.dart';

@freezed
abstract class NewWalletMetadataModel with _$NewWalletMetadataModel {
  const factory NewWalletMetadataModel({
    required String id,
    required String masterFingerprint,
    required String xpubFingerprint,
    required bool isEncryptedVaultTested,
    required bool isPhysicalBackupTested,
    int? latestEncryptedBackup,
    int? latestPhysicalBackup,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required NewWalletSource source,
    required bool isDefault,
    required String label,
    DateTime? syncedAt,
  }) = _NewWalletMetadataModel;

  const NewWalletMetadataModel._();
}

extension NewWalletMetadataModelExtension on NewWalletMetadataModel {
  ({String account, String fingerprint, Network network, ScriptType script})
  get decodeOrigin => WalletMetadataService.decodeOrigin(origin: id);

  String get account => decodeOrigin.account;
  String get fingerprint => decodeOrigin.fingerprint;
  Network get network => decodeOrigin.network;
  ScriptType get scriptType => decodeOrigin.script;
  bool get isBitcoin => decodeOrigin.network.isBitcoin;
  bool get isLiquid => decodeOrigin.network.isLiquid;
  bool get isMainnet => decodeOrigin.network.isMainnet;
  bool get isTestnet => decodeOrigin.network.isTestnet;
}

extension NewWalletMetadataModelMapper on NewWalletMetadataModel {
  V5MigrateWalletMetadataRow toSqlite() => V5MigrateWalletMetadataRow(
    id: id,
    masterFingerprint: masterFingerprint,
    xpubFingerprint: xpubFingerprint,
    isEncryptedVaultTested: isEncryptedVaultTested,
    isPhysicalBackupTested: isPhysicalBackupTested,
    latestEncryptedBackup: latestEncryptedBackup,
    latestPhysicalBackup: latestPhysicalBackup,
    xpub: xpub,
    externalPublicDescriptor: externalPublicDescriptor,
    internalPublicDescriptor: internalPublicDescriptor,
    source: source,
    isDefault: isDefault,
    label: label,
    syncedAt: syncedAt,
  );

  static NewWalletMetadataModel fromSqlite(V5MigrateWalletMetadataRow row) =>
      NewWalletMetadataModel(
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
        source: row.source,
        isDefault: row.isDefault,
        label: row.label,
        syncedAt: row.syncedAt,
      );
}
