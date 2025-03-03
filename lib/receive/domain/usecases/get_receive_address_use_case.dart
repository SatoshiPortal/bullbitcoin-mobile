import 'package:bb_mobile/_core/domain/entities/address.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_manager_repository.dart';

class GetReceiveAddressUseCase {
  final WalletManagerRepository _walletManager;

  GetReceiveAddressUseCase({required WalletManagerRepository walletManager})
      : _walletManager = walletManager;

  Future<Address> execute(
      {required String walletId, bool newAddress = false}) async {
    Address address;
    if (!newAddress) {
      address = await _walletManager.getLastUnusedAddress(walletId: walletId);
    } else {
      address = await _walletManager.getNewAddress(walletId: walletId);
    }

    return address;
  }
}
