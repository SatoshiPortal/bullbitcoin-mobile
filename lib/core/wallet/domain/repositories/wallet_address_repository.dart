import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';

abstract class WalletAddressRepository {
  Future<WalletAddress> getLastUnusedReceiveAddress({
    required WalletModel wallet,
  });
  Future<WalletAddress> generateNewReceiveAddress({required String walletId});
  Future<List<WalletAddress>> getGeneratedReceiveAddresses(
    String walletId, {
    int? limit,
    int offset = 0,
    required bool descending,
  });
  Future<List<WalletAddress>> getUsedChangeAddresses(
    String walletId, {
    int? limit,
    int offset = 0,
    required bool descending,
  });
}
