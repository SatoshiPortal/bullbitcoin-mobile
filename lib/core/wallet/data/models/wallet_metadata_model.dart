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
    int? latestEncryptedBackup,
    int? latestPhysicalBackup,
    required String scriptType,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required String source,
    @Default(false) bool isDefault,
    @Default('') String label,
    DateTime? syncedAt,
  }) = _WalletMetadataModel;
  const WalletMetadataModel._();

  factory WalletMetadataModel.fromJson(Map<String, Object?> json) =>
      _$WalletMetadataModelFromJson(json);
}
