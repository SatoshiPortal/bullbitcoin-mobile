import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';

abstract class WalletAddressRepository {
  Future<WalletAddress> getNewAddress({
    required String walletId,
  });
  Future<WalletAddress> getLastUnusedAddress({
    required String walletId,
  });
  Future<List<WalletAddress>> getAddresses({
    required String walletId,
    required int limit,
    required int offset,
    required WalletAddressKeyChain keyChain,
  });
}
