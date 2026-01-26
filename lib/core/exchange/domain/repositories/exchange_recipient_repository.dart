import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';

abstract class ExchangeRecipientRepository {
  /// Get all default wallets (Bitcoin, Lightning, Liquid)
  Future<DefaultWallets> getDefaultWallets();

  /// Create or update a default wallet address
  Future<DefaultWallet> saveDefaultWallet({
    required WalletAddressType walletType,
    required String address,
    String? existingRecipientId,
  });

  /// Remove a wallet as default (sets isDefault to false)
  Future<void> deleteDefaultWallet({
    required String recipientId,
    required WalletAddressType walletType,
    required String address,
  });
}
