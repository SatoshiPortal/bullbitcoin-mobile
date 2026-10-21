import 'package:bb_mobile/core/exchange/data/exchange_json_decoder.dart';
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
    String? address = decodeExchangeJson<String?>(json['address']);
    address ??= decodeExchangeJson<String?>(json['bitcoinAddress']);
    address ??= decodeExchangeJson<String?>(json['lightningAddress']);
    address ??= decodeExchangeJson<String?>(json['liquidAddress']);

    return RecipientModel(
      recipientId: decodeExchangeJson<String>(json['recipientId']),
      userId: decodeExchangeJson<String?>(json['userId']),
      recipientType: decodeExchangeJson<String>(json['recipientType']),
      address: address,
      isOwner: decodeExchangeJson<bool?>(json['isOwner']) ?? false,
      isDefault: decodeExchangeJson<bool?>(json['isDefault']) ?? false,
      createdAt: decodeExchangeJson<String?>(json['createdAt']),
      updatedAt: decodeExchangeJson<String?>(json['updatedAt']),
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
