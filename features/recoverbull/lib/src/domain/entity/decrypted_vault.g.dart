// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'decrypted_vault.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DecryptedVault _$DecryptedVaultFromJson(Map<String, dynamic> json) =>
    _DecryptedVault(
      mnemonic:
          (json['mnemonic'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      masterFingerprint: json['masterFingerprint'] as String? ?? '',
      isEncryptedVaultTested: json['isEncryptedVaultTested'] as bool? ?? false,
      isPhysicalBackupTested: json['isPhysicalBackupTested'] as bool? ?? false,
      latestEncryptedBackup: json['latestEncryptedBackup'] == null
          ? null
          : DateTime.parse(json['latestEncryptedBackup'] as String),
      latestPhysicalBackup: json['latestPhysicalBackup'] == null
          ? null
          : DateTime.parse(json['latestPhysicalBackup'] as String),
    );

Map<String, dynamic> _$DecryptedVaultToJson(
  _DecryptedVault instance,
) => <String, dynamic>{
  'mnemonic': instance.mnemonic,
  'masterFingerprint': instance.masterFingerprint,
  'isEncryptedVaultTested': instance.isEncryptedVaultTested,
  'isPhysicalBackupTested': instance.isPhysicalBackupTested,
  'latestEncryptedBackup': instance.latestEncryptedBackup?.toIso8601String(),
  'latestPhysicalBackup': instance.latestPhysicalBackup?.toIso8601String(),
};
