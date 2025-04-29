import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_address_repository.dart';

class GetUsedReceiveAddressesUsecase {
  final WalletAddressRepository _walletAddressRepository;

  GetUsedReceiveAddressesUsecase({
    required WalletAddressRepository walletAddressRepository,
  }) : _walletAddressRepository = walletAddressRepository;

  Future<List<WalletAddress>> execute({
    required String walletId,
    int? limit,
    int? offset,
  }) async {
    try {
      final address = await _walletAddressRepository.getLastUnusedAddress(
        walletId: walletId,
      );
      final index = address.index;

      final usedAddresses = await _walletAddressRepository.getAddresses(
        walletId: walletId,
        limit: index,
        offset: 0,
        keyChain: WalletAddressKeyChain.external,
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
