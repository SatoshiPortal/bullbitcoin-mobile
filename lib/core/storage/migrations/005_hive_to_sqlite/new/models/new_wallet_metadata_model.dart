import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/entities/new_wallet_metadata_entity.dart';
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
    required dynamic source,
    required bool isDefault,
    required String label,
    DateTime? syncedAt,
  }) = _NewWalletMetadataModel;

  const NewWalletMetadataModel._();
}

extension NewWalletMetadataModelExtension on NewWalletMetadataModel {
  ({
    String account,
    String fingerprint,
    NewNetwork network,
    NewScriptType script,
  })
  get decodeOrigin => throw UnimplementedError();

  String get account => decodeOrigin.account;
  String get fingerprint => decodeOrigin.fingerprint;
  NewNetwork get network => decodeOrigin.network;
  NewScriptType get scriptType => decodeOrigin.script;
  bool get isBitcoin => decodeOrigin.network.isBitcoin;
  bool get isLiquid => decodeOrigin.network.isLiquid;
  bool get isMainnet => decodeOrigin.network.isMainnet;
  bool get isTestnet => decodeOrigin.network.isTestnet;
}
