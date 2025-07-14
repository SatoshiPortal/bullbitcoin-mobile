import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';

class GetAddressListUsecase {
  final WalletAddressRepository _walletAddressRepository;

  const GetAddressListUsecase({
    required WalletAddressRepository walletAddressRepository,
  }) : _walletAddressRepository = walletAddressRepository;

  Future<List<WalletAddress>> execute({
    required String walletId,
    bool isChange = false,
    int? limit,
    int? offset,
  }) {
    try {
      if (isChange) {
        return _walletAddressRepository.getUsedChangeAddresses(
          walletId,
          limit: limit,
          offset: offset ?? 0,
          descending: true,
        );
      } else {
        return _walletAddressRepository.getGeneratedReceiveAddresses(
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
