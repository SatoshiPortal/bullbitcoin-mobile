import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/address_repository.dart';

class GetReceiveAddressUsecase {
  final AddressRepository _addressRepository;

  GetReceiveAddressUsecase({
    required AddressRepository addressRepository,
  }) : _addressRepository = addressRepository;

  Future<Address> execute({
    required String walletId,
    bool newAddress = false,
  }) async {
    try {
      Address address;
      if (!newAddress) {
        address =
            await _addressRepository.getLastUnusedAddress(walletId: walletId);
      } else {
        address = await _addressRepository.getNewAddress(walletId: walletId);
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
