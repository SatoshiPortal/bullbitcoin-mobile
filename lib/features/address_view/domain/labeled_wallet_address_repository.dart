import 'wallet_address.dart';

abstract interface class LabeledWalletAddressRepository {
  Future<WalletAddress> getLastRevealedReceiveAddress({
    required String walletId,
  });
  Future<WalletAddress> generateNewReceiveAddress({required String walletId});
  Future<List<WalletAddress>> getGeneratedReceiveAddresses(
    String walletId, {
    int? limit,
    int? fromIndex,
  });
  Future<List<WalletAddress>> getUsedChangeAddresses(
    String walletId, {
    int? limit,
    int? fromIndex,
    required bool descending,
  });
  Future<WalletAddress> getAddressAtIndex({
    required String walletId,
    required int index,
    required bool isChange,
  });
}
