import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/json.dart';
import 'package:meta/meta.dart';

/// A recipient as `listMyRecipients`, `createMyRecipient` and
/// `updateMyRecipient` return it, with the server's raw values. The address
/// can be in [address] or in the field of its [recipientType].
@immutable
class MyRecipient {
  final String recipientId;
  final String? userId;

  /// For example `OUT_BITCOIN_ADDRESS`.
  final String recipientType;
  final String? address;
  final String? bitcoinAddress;
  final String? lightningAddress;
  final String? liquidAddress;
  final bool? isOwner;
  final bool? isDefault;
  final String? createdAt;
  final String? updatedAt;

  const MyRecipient({
    required this.recipientId,
    this.userId,
    required this.recipientType,
    this.address,
    this.bitcoinAddress,
    this.lightningAddress,
    this.liquidAddress,
    this.isOwner,
    this.isDefault,
    this.createdAt,
    this.updatedAt,
  });

  /// Throws a [BbxApiFormatException] naming the first invalid field.
  factory MyRecipient.fromJson(Map<String, dynamic> json) => MyRecipient(
    recipientId: read<String>(json['recipientId'], 'recipientId'),
    userId: read<String?>(json['userId'], 'userId'),
    recipientType: read<String>(json['recipientType'], 'recipientType'),
    address: read<String?>(json['address'], 'address'),
    bitcoinAddress: read<String?>(json['bitcoinAddress'], 'bitcoinAddress'),
    lightningAddress: read<String?>(
      json['lightningAddress'],
      'lightningAddress',
    ),
    liquidAddress: read<String?>(json['liquidAddress'], 'liquidAddress'),
    isOwner: read<bool?>(json['isOwner'], 'isOwner'),
    isDefault: read<bool?>(json['isDefault'], 'isDefault'),
    createdAt: read<String?>(json['createdAt'], 'createdAt'),
    updatedAt: read<String?>(json['updatedAt'], 'updatedAt'),
  );
}
