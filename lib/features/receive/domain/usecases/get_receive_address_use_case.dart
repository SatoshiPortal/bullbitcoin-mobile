import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class GetReceiveAddressUsecase {
  final WalletRepository _walletRepository;

  GetReceiveAddressUsecase({required WalletRepository walletRepository})
      : _walletRepository = walletRepository;

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
