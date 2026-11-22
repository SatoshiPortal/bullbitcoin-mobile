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
}
