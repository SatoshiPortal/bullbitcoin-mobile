import 'package:freezed_annotation/freezed_annotation.dart';

part 'default_wallet_address.freezed.dart';

/// Type of wallet address for default Bitcoin wallets
enum WalletAddressType {
  bitcoin('Bitcoin'),
  lightning('Lightning'),
  liquid('Liquid');

  const WalletAddressType(this.displayName);
  final String displayName;
}

/// Represents a default wallet address for receiving Bitcoin
@freezed
sealed class DefaultWalletAddress with _$DefaultWalletAddress {
  const DefaultWalletAddress._();

  const factory DefaultWalletAddress({
    required String recipientId,
    required WalletAddressType addressType,
    required String address,
    @Default(true) bool isDefault,
    @Default(true) bool isOwner,
    String? label,
  }) = _DefaultWalletAddress;

  /// Whether this is a valid address (non-empty)
  bool get hasAddress => address.isNotEmpty;

  /// Get a shortened version of the address for display
  String get shortAddress {
    if (address.isEmpty) return '';
    if (address.contains('@')) return address; // Lightning address
    if (address.length <= 16) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }
}

/// Holds all default wallet addresses for a user
@freezed
sealed class DefaultWallets with _$DefaultWallets {
  const DefaultWallets._();

  const factory DefaultWallets({
    DefaultWalletAddress? bitcoin,
    DefaultWalletAddress? lightning,
    DefaultWalletAddress? liquid,
  }) = _DefaultWallets;

  /// Get address by type
  DefaultWalletAddress? getByType(WalletAddressType type) {
    switch (type) {
      case WalletAddressType.bitcoin:
        return bitcoin;
      case WalletAddressType.lightning:
        return lightning;
      case WalletAddressType.liquid:
        return liquid;
    }
  }

  /// Check if any default wallet is configured
  bool get hasAnyWallet =>
      (bitcoin?.hasAddress ?? false) ||
      (lightning?.hasAddress ?? false) ||
      (liquid?.hasAddress ?? false);
}

