import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_metadata_model.freezed.dart';
part 'wallet_metadata_model.g.dart';

@freezed
class WalletMetadataModel with _$WalletMetadataModel {
  factory WalletMetadataModel({
    @Default('') String masterFingerprint,
    required String xpubFingerprint,
    required bool isBitcoin,
    required bool isLiquid,
    required bool isMainnet,
    required bool isTestnet,
    @Default(false) bool isEncryptedVaultTested,
    @Default(false) bool isPhysicalBackupTested,
    int? lastestEncryptedBackup,
    int? lastestPhysicalBackup,
    required String scriptType,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required String source,
    @Default(false) bool isDefault,
    @Default('') String label,
  }) = _WalletMetadataModel;
  const WalletMetadataModel._();

  factory WalletMetadataModel.fromJson(Map<String, Object?> json) =>
      _$WalletMetadataModelFromJson(json);

  // The network name is important since the same coin type and script types
  //  are used in for example bitcoin and liquid testnet, so we need to include
  //  the network name in the id to differentiate wallets from different
  //  networks with the same xpub/seed.
  String get id =>
      '$xpubFingerprint:${isLiquid ? 'liquid' : 'bitcoin'}:${isTestnet ? 'testnet' : 'mainnet'}';

  factory WalletMetadataModel.fromEntity(WalletMetadata entity) {
    return WalletMetadataModel(
      masterFingerprint: entity.masterFingerprint,
      xpubFingerprint: entity.xpubFingerprint,
      isBitcoin: entity.network.isBitcoin,
      isLiquid: entity.network.isLiquid,
      isMainnet: entity.network.isMainnet,
      isTestnet: entity.network.isTestnet,
      scriptType: entity.scriptType.name,
      xpub: entity.xpub,
      isEncryptedVaultTested: entity.isEncryptedVaultTested,
      isPhysicalBackupTested: entity.isPhysicalBackupTested,
      lastestEncryptedBackup:
          entity.lastestEncryptedBackup?.toUtc().millisecondsSinceEpoch,
      lastestPhysicalBackup:
          entity.lastestPhysicalBackup?.toUtc().millisecondsSinceEpoch,
      externalPublicDescriptor: entity.externalPublicDescriptor,
      internalPublicDescriptor: entity.internalPublicDescriptor,
      source: entity.source.name,
      isDefault: entity.isDefault,
      label: entity.label,
    );
  }

  WalletMetadata toEntity() {
    return WalletMetadata(
      id: id,
      masterFingerprint: masterFingerprint,
      xpubFingerprint: xpubFingerprint,
      network: Network.fromEnvironment(
        isTestnet: isTestnet,
        isLiquid: isLiquid,
      ),
      isEncryptedVaultTested: isEncryptedVaultTested,
      isPhysicalBackupTested: isPhysicalBackupTested,
      lastestEncryptedBackup: lastestEncryptedBackup != null
          ? DateTime.fromMillisecondsSinceEpoch(lastestEncryptedBackup!)
          : null,
      lastestPhysicalBackup: lastestPhysicalBackup != null
          ? DateTime.fromMillisecondsSinceEpoch(lastestPhysicalBackup!)
          : null,
      scriptType: ScriptType.fromName(scriptType),
      xpub: xpub,
      externalPublicDescriptor: externalPublicDescriptor,
      internalPublicDescriptor: internalPublicDescriptor,
      source: WalletSource.fromName(source),
      isDefault: isDefault,
      label: label,
    );
  }
}
