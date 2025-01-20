import 'package:bb_mobile/features/wallet/domain/entities/wallet_metadata.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_metadata_model.freezed.dart';
part 'wallet_metadata_model.g.dart';

@freezed
class WalletMetadataModel with _$WalletMetadataModel {
  factory WalletMetadataModel({
    required String id,
    required String type,
    required String name,
  }) = _WalletMetadataModel;
  const WalletMetadataModel._();

  factory WalletMetadataModel.fromJson(Map<String, Object?> json) =>
      _$WalletMetadataModelFromJson(json);

  factory WalletMetadataModel.fromEntity(WalletMetadata entity) {
    return WalletMetadataModel(
      id: entity.id,
      type: entity.type == WalletType.bdk ? 'bdk' : 'lwk',
      name: entity.name,
    );
  }

  WalletMetadata toEntity() {
    return WalletMetadata(
      id: id,
      type: type == 'bdk' ? WalletType.bdk : WalletType.lwk,
      name: name,
    );
  }
}
