import 'package:bb_mobile/_core/domain/entities/address.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';

class GetReceiveAddressUsecase {
  final WalletManagerService _walletManager;

  GetReceiveAddressUsecase({required WalletManagerService walletManager})
      : _walletManager = walletManager;

  Future<Address> execute({
    required String walletId,
    bool newAddress = false,
  }) async {
    try {
      Address address;
      if (!newAddress) {
        address = await _walletManager.getLastUnusedAddress(walletId: walletId);
      } else {
        address = await _walletManager.getNewAddress(walletId: walletId);
      }

      return address;
    } catch (e) {
      throw GetReceiveAddressException(e.toString());
    }
  }
}

class GetReceiveAddressException implements Exception {
  final String? message;

  GetReceiveAddressException(this.message);
}
