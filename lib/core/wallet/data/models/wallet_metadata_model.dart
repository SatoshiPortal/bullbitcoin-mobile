import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_metadata_model.freezed.dart';

@freezed
abstract class WalletMetadataModel with _$WalletMetadataModel {
  const factory WalletMetadataModel({
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
    required Signer signer,
    required bool isDefault,
    @Default(0) int lastReceiveAddressIndex,
    String? label,
    DateTime? syncedAt,
    SignerDevice? signerDevice,
  }) = _WalletMetadataModel;

  const WalletMetadataModel._();
}

extension WalletMetadataModelExtension on WalletMetadataModel {
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

extension WalletMetadataModelMapper on WalletMetadataModel {
  WalletMetadataRow toSqlite() => WalletMetadataRow(
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
    signer: signer.name,
    isDefault: isDefault,
    label: label ?? '',
    syncedAt: syncedAt,
    signerDevice: signerDevice,
  );

  static WalletMetadataModel fromSqlite(WalletMetadataRow row) =>
      WalletMetadataModel(
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
        signer: Signer.fromName(row.signer),
        isDefault: row.isDefault,
        label: row.label,
        syncedAt: row.syncedAt,
        signerDevice: row.signerDevice,
      );
}
