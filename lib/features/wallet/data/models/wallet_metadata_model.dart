import 'package:bb_mobile/features/wallet/domain/entities/wallet_metadata.dart';

class WalletMetadataModel {
  final String id;
  final String type;
  final String name;

  WalletMetadataModel({
    required this.id,
    required this.type,
    required this.name,
  });

  WalletMetadata toDomain() {
    return WalletMetadata(
      id: id,
      type: type == 'bdk' ? WalletType.bdk : WalletType.lwk,
      name: name,
    );
  }

  factory WalletMetadataModel.fromJson(Map<String, dynamic> json) {
    return WalletMetadataModel(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
    );
  }
}
