import 'package:bb_mobile/core/wallet/domain/entities/address_details.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/address_list_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';

class GetAddressListUsecase {
  final AddressListRepository _addressListRepository;

  const GetAddressListUsecase({
    required AddressListRepository addressListRepository,
  }) : _addressListRepository = addressListRepository;

  Future<List<AddressDetails>> execute({
    required String walletId,
    bool isChange = false,
    int? limit,
    int? offset,
  }) {
    try {
      if (isChange) {
        return _addressListRepository.getUsedChangeAddresses(
          walletId,
          limit: limit,
          offset: offset ?? 0,
        );
      } else {
        return _addressListRepository.getUsedReceiveAddresses(
          walletId,
          limit: limit,
          offset: offset ?? 0,
        );
      }
    } on WalletError {
      rethrow;
    } catch (e) {
      // Handle exceptions as needed
      throw WalletError.unexpected('Failed to get address list: $e');
    }
  }
}
