import 'package:bb_mobile/core/wallet/domain/entity/address.dart';

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
