import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet_address.dart';

class GetAddressAtIndexUsecase {
  final WalletAddressRepository _walletAddressRepository;

  GetAddressAtIndexUsecase({
    required WalletAddressRepository walletAddressRepository,
  }) : _walletAddressRepository = walletAddressRepository;

  Future<WalletAddress> execute({
    required String walletId,
    required int index,
  }) async {
    try {
      final address = await _walletAddressRepository.getAddressAtIndex(
        walletId: walletId,
        index: index,
      );

      return address;
    } catch (e) {
      throw GetAddressAtIndexException(e.toString());
    }
  }
}

class GetAddressAtIndexException extends BullException {
  GetAddressAtIndexException(super.message);
}
