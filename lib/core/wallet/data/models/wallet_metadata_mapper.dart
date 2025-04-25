import 'package:bb_mobile/core/storage/sqlite_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_extension.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';

class WalletMetadataMapper {
  static WalletMetadata fromModelToSqlite(WalletMetadataModel model) {
    return WalletMetadata(
      id: model.id,
      masterFingerprint: model.masterFingerprint,
      xpubFingerprint: model.xpubFingerprint,
      isBitcoin: model.isBitcoin,
      isLiquid: model.isLiquid,
      isMainnet: model.isMainnet,
      isTestnet: model.isTestnet,
      isEncryptedVaultTested: model.isEncryptedVaultTested,
      isPhysicalBackupTested: model.isPhysicalBackupTested,
      scriptType: model.scriptType,
      xpub: model.xpub,
      externalPublicDescriptor: model.externalPublicDescriptor,
      internalPublicDescriptor: model.internalPublicDescriptor,
      source: model.source,
      isDefault: model.isDefault,
      label: model.label,
    );
  }

  static WalletMetadataModel fromSqliteToModel(WalletMetadata metadata) {
    return WalletMetadataModel(
      xpubFingerprint: metadata.xpubFingerprint,
      isBitcoin: metadata.isBitcoin,
      isLiquid: metadata.isLiquid,
      isMainnet: metadata.isMainnet,
      isTestnet: metadata.isTestnet,
      scriptType: metadata.scriptType,
      xpub: metadata.xpub,
      externalPublicDescriptor: metadata.externalPublicDescriptor,
      internalPublicDescriptor: metadata.internalPublicDescriptor,
      source: metadata.source,
    );
  }
}
