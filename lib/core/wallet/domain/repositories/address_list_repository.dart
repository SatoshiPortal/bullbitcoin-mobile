import 'package:bb_mobile/core/wallet/domain/entities/address_details.dart';

abstract class AddressListRepository {
  Future<List<AddressDetails>> getUsedReceiveAddresses(
    String walletId, {
    int? limit,
    int offset = 0,
    bool descending = true,
  });

  Future<List<AddressDetails>> getUsedChangeAddresses(
    String walletId, {
    int? limit,
    int offset = 0,
    bool descending = true,
  });
}
