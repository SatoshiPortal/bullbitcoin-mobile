import 'package:bb_mobile/core/address/domain/entities/address.dart';
import 'package:bb_mobile/core/address/domain/repositories/address_repository.dart';

class GetReceiveAddressUsecase {
  final AddressRepository _addressRepository;

  GetReceiveAddressUsecase({
    required AddressRepository addressRepository,
  }) : _addressRepository = addressRepository;

  Future<Address> execute({
    required String origin,
    bool newAddress = false,
  }) async {
    try {
      Address address;
      if (!newAddress) {
        address = await _addressRepository.getLastUnusedAddress(origin: origin);
      } else {
        address = await _addressRepository.getNewAddress(origin: origin);
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
