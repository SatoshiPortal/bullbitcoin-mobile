import 'wallet_metadata.dart';

/// Metadata persistence supplied by the host, without access to native wallets.
abstract interface class WalletCatalogPort {
  Future<void> store(WalletMetadata metadata);
  Future<WalletMetadata?> fetch(String walletId);
  Future<List<WalletMetadata>> fetchAll();
  Future<void> delete(String walletId);
}
