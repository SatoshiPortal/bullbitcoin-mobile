import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/features/address_view/domain/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/features/address_view/domain/wallet_address.dart';

class GetAddressAtIndexUsecase {
  final WalletAddressRepository _walletAddressRepository;

  GetAddressAtIndexUsecase({required this._walletAddressRepository});

  Future<WalletAddress> execute({
    required String walletId,
    required int index,
  }) async {
    try {
      final address = await _walletAddressRepository.getAddressAtIndex(
        walletId: walletId,
        index: index,
        isChange: false,
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
