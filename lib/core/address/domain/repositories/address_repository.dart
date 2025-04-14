import 'package:bb_mobile/core/address/domain/entities/address.dart';

abstract class AddressRepository {
  Future<Address> getNewAddress({
    required String origin,
  });
  Future<Address> getLastUnusedAddress({
    required String origin,
  });
  Future<List<Address>> getAddresses({
    required String origin,
    required int limit,
    required int offset,
    required AddressKeyChain keyChain,
  });
}
