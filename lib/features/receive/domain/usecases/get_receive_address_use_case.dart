import 'package:bb_mobile/core/domain/entities/address.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';

class GetReceiveAddressUseCase {
  final WalletRepositoryManager _walletRepositoryManager;

  GetReceiveAddressUseCase(
      {required WalletRepositoryManager walletRepositoryManager})
      : _walletRepositoryManager = walletRepositoryManager;

  Future<Address> execute(
      {required String walletId, bool newAddress = false}) async {
    final wallet = _walletRepositoryManager.getRepository(walletId);

    // TODO: move this to getRepository function so it throws an exception if wallet is not found instead of returning null
    if (wallet == null) {
      throw Exception('Wallet not found');
    }

    Address address;
    if (!newAddress) {
      address = await wallet.getLastUnusedAddress();
    } else {
      address = await wallet.getNewAddress();
    }

    return address;
  }
}
