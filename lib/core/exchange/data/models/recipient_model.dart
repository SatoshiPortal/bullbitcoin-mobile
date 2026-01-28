import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';

/// Model for API recipient response
class RecipientModel {
  final String recipientId;
  final String? userId;
  final String recipientType;
  final String? address;
  final bool isOwner;
  final bool isDefault;
  final String? createdAt;
  final String? updatedAt;

  const RecipientModel({
    required this.recipientId,
    this.userId,
    required this.recipientType,
    this.address,
    required this.isOwner,
    required this.isDefault,
    this.createdAt,
    this.updatedAt,
  });

  factory RecipientModel.fromJson(Map<String, dynamic> json) {
    // Address can be in different fields based on recipient type
    String? address = json['address'] as String?;
    address ??= json['bitcoinAddress'] as String?;
    address ??= json['lightningAddress'] as String?;
    address ??= json['liquidAddress'] as String?;

    return RecipientModel(
      recipientId: json['recipientId'] as String,
      userId: json['userId'] as String?,
      recipientType: json['recipientType'] as String,
      address: address,
      isOwner: json['isOwner'] as bool? ?? false,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  DefaultWallet toEntity() {
    return DefaultWallet(
      recipientId: recipientId,
      walletType: _parseWalletType(recipientType),
      address: address ?? '',
      isDefault: isDefault,
    );
  }

  static WalletAddressType _parseWalletType(String recipientType) {
    switch (recipientType) {
      case 'OUT_BITCOIN_ADDRESS':
        return WalletAddressType.bitcoin;
      case 'OUT_LIGHTNING_ADDRESS':
        return WalletAddressType.lightning;
      case 'OUT_LIQUID_ADDRESS':
        return WalletAddressType.liquid;
      default:
        return WalletAddressType.bitcoin;
    }
  }
}

