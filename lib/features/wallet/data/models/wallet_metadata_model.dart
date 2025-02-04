import 'package:bb_mobile/features/wallet/domain/entities/wallet_metadata.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_metadata_model.freezed.dart';
part 'wallet_metadata_model.g.dart';

@freezed
class WalletMetadataModel with _$WalletMetadataModel {
  factory WalletMetadataModel({
    required String id,
    required String label,
    required String seedFingerprint,
    required String network,
    required String environment,
    required String scriptType,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required String source,
  }) = _WalletMetadataModel;
  const WalletMetadataModel._();

  factory WalletMetadataModel.fromJson(Map<String, Object?> json) =>
      _$WalletMetadataModelFromJson(json);

  factory WalletMetadataModel.fromEntity(WalletMetadata entity) {
    return WalletMetadataModel(
      id: entity.id,
      label: entity.label,
      seedFingerprint: entity.seedFingerprint,
      network: entity.network.name,
      environment: entity.environment.name,
      scriptType: entity.scriptType.name,
      externalPublicDescriptor: entity.externalPublicDescriptor,
      internalPublicDescriptor: entity.internalPublicDescriptor,
      source: entity.source.name,
    );
  }

  WalletMetadata toEntity() {
    return WalletMetadata(
      id: id,
      label: label,
      seedFingerprint: seedFingerprint,
      network: Network.fromName(network),
      environment: NetworkEnvironment.fromName(environment),
      scriptType: WalletScriptType.fromName(scriptType),
      externalPublicDescriptor: externalPublicDescriptor,
      internalPublicDescriptor: internalPublicDescriptor,
      source: WalletSource.fromName(source),
    );
  }
}
