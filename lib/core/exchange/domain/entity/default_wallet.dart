/// Represents the type of wallet address
enum WalletAddressType {
  bitcoin,
  lightning,
  liquid;

  String get displayName {
    switch (this) {
      case WalletAddressType.bitcoin:
        return 'Bitcoin';
      case WalletAddressType.lightning:
        return 'Lightning';
      case WalletAddressType.liquid:
        return 'Liquid';
    }
  }

  String get recipientTypeValue {
    switch (this) {
      case WalletAddressType.bitcoin:
        return 'OUT_BITCOIN_ADDRESS';
      case WalletAddressType.lightning:
        return 'OUT_LIGHTNING_ADDRESS';
      case WalletAddressType.liquid:
        return 'OUT_LIQUID_ADDRESS';
    }
  }

  String get addressHint {
    switch (this) {
      case WalletAddressType.bitcoin:
        return 'bc1...';
      case WalletAddressType.lightning:
        return 'user@domain.com or lnurl...';
      case WalletAddressType.liquid:
        return 'lq1...';
    }
  }
}

/// Entity representing a default wallet address
class DefaultWallet {
  final String? recipientId;
  final WalletAddressType walletType;
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
    WalletAddressType? walletType,
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

/// Entity representing all default wallets for a user
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

  DefaultWallet? getWallet(WalletAddressType type) {
    switch (type) {
      case WalletAddressType.bitcoin:
        return bitcoin;
      case WalletAddressType.lightning:
        return lightning;
      case WalletAddressType.liquid:
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
