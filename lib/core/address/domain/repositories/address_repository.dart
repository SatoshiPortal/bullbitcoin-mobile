import 'package:bb_mobile/core/address/domain/entities/address.dart';

abstract class AddressRepository {
  Future<Address> getNewAddress({
    required String walletId,
  });
  Future<Address> getLastUnusedAddress({
    required String walletId,
  });
  Future<List<Address>> getAddresses({
    required String walletId,
    required int limit,
    required int offset,
    required AddressKeyChain keyChain,
  });
}
