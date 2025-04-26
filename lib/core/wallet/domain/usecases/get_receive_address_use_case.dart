import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_address_repository.dart';

class GetReceiveAddressUsecase {
  final WalletAddressRepository _walletAddressRepository;

  GetReceiveAddressUsecase({
    required WalletAddressRepository walletAddressRepository,
  }) : _walletAddressRepository = walletAddressRepository;

  Future<WalletAddress> execute({
    required String walletId,
    bool newAddress = false,
  }) async {
    try {
      WalletAddress address;
      if (!newAddress) {
        address = await _walletAddressRepository.getLastUnusedAddress(
            walletId: walletId);
      } else {
        address =
            await _walletAddressRepository.getNewAddress(walletId: walletId);
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
