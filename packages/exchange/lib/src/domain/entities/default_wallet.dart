import 'btc_network.dart';

/// A default Exchange payout destination, not a local wallet.
class DefaultWallet {
  final String? recipientId;
  final BtcNetwork walletType;
  final String address;
  final bool isDefault;

  const DefaultWallet({
    this.recipientId,
    required this.walletType,
    required this.address,
    this.isDefault = true,
  });

  bool get isEmpty => address.isEmpty;
  bool get isNotEmpty => address.isNotEmpty;

  DefaultWallet copyWith({
    String? recipientId,
    BtcNetwork? walletType,
    String? address,
    bool? isDefault,
  }) {
    return DefaultWallet(
      recipientId: recipientId ?? this.recipientId,
      walletType: walletType ?? this.walletType,
      address: address ?? this.address,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DefaultWallet &&
        other.recipientId == recipientId &&
        other.walletType == walletType &&
        other.address == address &&
        other.isDefault == isDefault;
  }

  @override
  int get hashCode => Object.hash(recipientId, walletType, address, isDefault);
}

/// The default Exchange payout destinations for a user.
class DefaultWallets {
  final DefaultWallet? bitcoin;
  final DefaultWallet? lightning;
  final DefaultWallet? liquid;

  const DefaultWallets({this.bitcoin, this.lightning, this.liquid});

  String get bitcoinAddress => bitcoin?.address ?? '';
  String get lightningAddress => lightning?.address ?? '';
  String get liquidAddress => liquid?.address ?? '';

  bool get hasAnyWallet =>
      bitcoinAddress.isNotEmpty ||
      lightningAddress.isNotEmpty ||
      liquidAddress.isNotEmpty;

  DefaultWallet? getWallet(BtcNetwork type) {
    switch (type) {
      case BtcNetwork.bitcoin:
        return bitcoin;
      case BtcNetwork.lightning:
        return lightning;
      case BtcNetwork.liquid:
        return liquid;
    }
  }

  DefaultWallets copyWith({
    DefaultWallet? bitcoin,
    DefaultWallet? lightning,
    DefaultWallet? liquid,
  }) {
    return DefaultWallets(
      bitcoin: bitcoin ?? this.bitcoin,
      lightning: lightning ?? this.lightning,
      liquid: liquid ?? this.liquid,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DefaultWallets &&
        other.bitcoin == bitcoin &&
        other.lightning == lightning &&
        other.liquid == liquid;
  }

  @override
  int get hashCode => Object.hash(bitcoin, lightning, liquid);
}
