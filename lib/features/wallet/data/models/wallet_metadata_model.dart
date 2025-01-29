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
    required String network,
    required String environment,
    required String scriptType,
    required String source,
  }) = _WalletMetadataModel;
  const WalletMetadataModel._();

  factory WalletMetadataModel.fromJson(Map<String, Object?> json) =>
      _$WalletMetadataModelFromJson(json);

  factory WalletMetadataModel.fromEntity(WalletMetadata entity) {
    return WalletMetadataModel(
      id: entity.id,
      label: entity.label,
      network: entity.network.name,
      environment: entity.environment.name,
      scriptType: entity.scriptType.name,
      source: entity.source.name,
    );
  }

  WalletMetadata toEntity() {
    return WalletMetadata(
      id: id,
      label: label,
      network: WalletNetwork.fromName(network),
      environment: WalletEnvironment.fromName(environment),
      scriptType: WalletScriptType.fromName(scriptType),
      source: WalletSource.fromName(source),
    );
  }
}
