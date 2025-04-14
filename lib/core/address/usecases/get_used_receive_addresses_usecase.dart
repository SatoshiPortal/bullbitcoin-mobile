import 'package:bb_mobile/core/address/domain/entities/address.dart';
import 'package:bb_mobile/core/address/domain/repositories/address_repository.dart';

class GetUsedReceiveAddressesUsecase {
  final AddressRepository _addressRepository;

  GetUsedReceiveAddressesUsecase({
    required AddressRepository addressRepository,
  }) : _addressRepository = addressRepository;

  Future<List<Address>> execute({
    required String origin,
    int? limit,
    int? offset,
  }) async {
    try {
      final address =
          await _addressRepository.getLastUnusedAddress(origin: origin);
      final index = address.index;

      final usedAddresses = await _addressRepository.getAddresses(
        origin: origin,
        limit: index,
        offset: 0,
        keyChain: AddressKeyChain.external,
      );

      return usedAddresses;
    } catch (e) {
      throw GetUsedReceiveAddressesException(e.toString());
    }
  }
}

class GetUsedReceiveAddressesException implements Exception {
  final String? message;

  GetUsedReceiveAddressesException(this.message);
}
