import 'package:bb_mobile/features/wallet/domain/entities/wallet_metadata.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_metadata_model.freezed.dart';
part 'wallet_metadata_model.g.dart';

@freezed
class WalletMetadataModel with _$WalletMetadataModel {
  factory WalletMetadataModel({
    required String masterFingerprint,
    required String network,
    required String scriptType,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required String source,
    String? label,
  }) = _WalletMetadataModel;
  const WalletMetadataModel._();

  factory WalletMetadataModel.fromJson(Map<String, Object?> json) =>
      _$WalletMetadataModelFromJson(json);

  factory WalletMetadataModel.fromEntity(WalletMetadata entity) {
    return WalletMetadataModel(
      label: entity.label,
      masterFingerprint: entity.masterFingerprint,
      network: entity.network.name,
      scriptType: entity.scriptType.name,
      xpub: entity.xpub,
      externalPublicDescriptor: entity.externalPublicDescriptor,
      internalPublicDescriptor: entity.internalPublicDescriptor,
      source: entity.source.name,
    );
  }

  WalletMetadata toEntity() {
    return WalletMetadata(
      label: label,
      masterFingerprint: masterFingerprint,
      network: Network.fromName(network),
      scriptType: ScriptType.fromName(scriptType),
      xpub: xpub,
      externalPublicDescriptor: externalPublicDescriptor,
      internalPublicDescriptor: internalPublicDescriptor,
      source: WalletSource.fromName(source),
    );
  }
}
