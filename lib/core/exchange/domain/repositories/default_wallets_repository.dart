import 'package:bb_mobile/core/exchange/domain/entity/default_wallet_address.dart';

/// Repository contract for managing default Bitcoin wallet addresses
abstract class DefaultWalletsRepository {
  /// Get all default wallet addresses for the user
  Future<DefaultWallets> getDefaultWallets();

  /// Save or update a default wallet address
  /// Returns the saved wallet address
  Future<DefaultWalletAddress> saveDefaultWallet({
    required WalletAddressType addressType,
    required String address,
    String? existingRecipientId,
  });

  /// Delete a default wallet address (marks as non-default)
  /// Returns true if deletion was successful
  Future<bool> deleteDefaultWallet({
    required String recipientId,
  });

  /// Validate a wallet address for the given type
  Future<bool> validateAddress({
    required WalletAddressType addressType,
    required String address,
  });
}






