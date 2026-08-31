import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_signer_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:drift/drift.dart' show Value;

extension WalletMetadataMapper on WalletMetadataModel {
  ScriptType? get inferredScriptType {
    final descriptor = publicDescriptor.trimLeft();
    if (descriptor.startsWith('wpkh(')) return ScriptType.bip84;
    if (descriptor.startsWith('sh(wpkh(')) return ScriptType.bip49;
    if (descriptor.startsWith('pkh(')) return ScriptType.bip44;
    try {
      return WalletMetadataService.decodeOrigin(origin: id).script;
    } on String {
      return null;
    }
  }

  WalletMetadatasCompanion toSqlite() => WalletMetadatasCompanion(
    id: Value(id),
    network: Value(network),
    isEncryptedVaultTested: Value(isEncryptedVaultTested),
    isPhysicalBackupTested: Value(isPhysicalBackupTested),
    latestEncryptedBackup: Value(latestEncryptedBackup),
    latestPhysicalBackup: Value(latestPhysicalBackup),
    publicDescriptor: Value(publicDescriptor),
    isDefault: Value(isDefault),
    isHidden: Value(isHidden),
    label: Value(label),
    syncedAt: Value(syncedAt),
    birthday: Value(birthday),
  );

  List<WalletSignersCompanion> signersToSqlite() => [
    for (final (position, signer) in signers.indexed)
      WalletSignersCompanion.insert(
        walletId: id,
        id: signer.id,
        position: position,
        signer: signer.signer,
        signerDevice: Value(signer.signerDevice),
      ),
  ];

  List<WalletDescriptorKeysCompanion> descriptorKeysToSqlite() => [
    for (final (position, key)
        in signers.expand((signer) => signer.descriptorKeys).indexed)
      WalletDescriptorKeysCompanion.insert(
        walletId: id,
        id: key.id,
        position: position,
        signerId: key.signerId,
        masterFingerprint: key.masterFingerprint,
        xpubFingerprint: key.xpubFingerprint,
        xpub: key.xpub,
        derivationPath: Value(key.derivationPath),
        descriptorPath: Value(key.descriptorPath),
      ),
  ];

  static WalletMetadataModel fromSqlite(
    WalletMetadataRow row,
    List<WalletSignerRow> signerRows,
    List<WalletDescriptorKeyRow> descriptorKeyRows,
  ) {
    final sortedSigners = [...signerRows]
      ..sort((first, second) => first.position.compareTo(second.position));
    final sortedKeys = [...descriptorKeyRows]
      ..sort((first, second) => first.position.compareTo(second.position));

    return WalletMetadataModel(
      id: row.id,
      network: row.network,
      signers: [
        for (final signer in sortedSigners)
          WalletSignerModel(
            id: signer.id,
            signer: signer.signer,
            signerDevice: signer.signerDevice,
            descriptorKeys: [
              for (final key in sortedKeys)
                if (key.signerId == signer.id)
                  WalletDescriptorKeyModel(
                    id: key.id,
                    signerId: key.signerId,
                    masterFingerprint: key.masterFingerprint,
                    xpubFingerprint: key.xpubFingerprint,
                    xpub: key.xpub,
                    derivationPath: key.derivationPath,
                    descriptorPath: key.descriptorPath,
                  ),
            ],
          ),
      ],
      isEncryptedVaultTested: row.isEncryptedVaultTested,
      isPhysicalBackupTested: row.isPhysicalBackupTested,
      latestEncryptedBackup: row.latestEncryptedBackup,
      latestPhysicalBackup: row.latestPhysicalBackup,
      publicDescriptor: row.publicDescriptor,
      isDefault: row.isDefault,
      isHidden: row.isHidden,
      label: row.label,
      syncedAt: row.syncedAt,
      birthday: row.birthday,
    );
  }
}
