import 'package:bb_mobile/core/wallet/data/models/wallet_signer_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_metadata_model.freezed.dart';

@freezed
abstract class WalletMetadataModel with _$WalletMetadataModel {
  const factory WalletMetadataModel({
    required String id,
    required Network network,
    required List<WalletSignerModel> signers,
    required bool isEncryptedVaultTested,
    required bool isPhysicalBackupTested,
    int? latestEncryptedBackup,
    int? latestPhysicalBackup,
    required String publicDescriptor,
    required bool isDefault,
    @Default(0) int lastReceiveAddressIndex,
    String? label,
    DateTime? syncedAt,
    DateTime? birthday,
  }) = _WalletMetadataModel;

  const WalletMetadataModel._();
}

extension WalletMetadataModelExtension on WalletMetadataModel {
  bool get isBitcoin => network.isBitcoin;
  bool get isLiquid => network.isLiquid;
  bool get isMainnet => network.isMainnet;
  bool get isTestnet => network.isTestnet;
}
