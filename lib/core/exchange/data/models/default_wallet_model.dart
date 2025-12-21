import 'package:bb_mobile/core/exchange/domain/entity/default_wallet_address.dart';

class DefaultWalletModel {
  final String recipientId;
  final String recipientType;
  final String? address;
  final bool isDefault;
  final bool isOwner;
  final String? label;

  DefaultWalletModel({
    required this.recipientId,
    required this.recipientType,
    this.address,
    this.isDefault = true,
    this.isOwner = true,
    this.label,
  });

  factory DefaultWalletModel.fromJson(Map<String, dynamic> json) {
    return DefaultWalletModel(
      recipientId: json['recipientId'] as String? ?? '',
      recipientType: json['recipientType'] as String? ?? '',
      address: json['address'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      isOwner: json['isOwner'] as bool? ?? true,
      label: json['label'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'recipientId': recipientId,
        'recipientType': recipientType,
        'address': address,
        'isDefault': isDefault,
        'isOwner': isOwner,
        'label': label,
      };

  WalletAddressType? get addressType {
    switch (recipientType) {
      case 'OUT_BITCOIN_ADDRESS':
        return WalletAddressType.bitcoin;
      case 'OUT_LIGHTNING_ADDRESS':
        return WalletAddressType.lightning;
      case 'OUT_LIQUID_ADDRESS':
        return WalletAddressType.liquid;
      default:
        return null;
    }
  }

  static String recipientTypeFromAddressType(WalletAddressType type) {
    switch (type) {
      case WalletAddressType.bitcoin:
        return 'OUT_BITCOIN_ADDRESS';
      case WalletAddressType.lightning:
        return 'OUT_LIGHTNING_ADDRESS';
      case WalletAddressType.liquid:
        return 'OUT_LIQUID_ADDRESS';
    }
  }

  DefaultWalletAddress? toEntity() {
    final type = addressType;
    if (type == null || address == null || address!.isEmpty) return null;

    return DefaultWalletAddress(
      recipientId: recipientId,
      addressType: type,
      address: address!,
      isDefault: isDefault,
      isOwner: isOwner,
      label: label,
    );
  }
}






