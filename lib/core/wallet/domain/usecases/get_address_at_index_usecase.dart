import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';

class GetAddressAtIndexUsecase {
  final WalletAddressRepository _walletAddressRepository;

  GetAddressAtIndexUsecase({required this._walletAddressRepository});

  Future<WalletAddress> execute({
    required String walletId,
    required int index,
    bool isChange = false,
  }) async {
    try {
      final address = await _walletAddressRepository.getAddressAtIndex(
        walletId: walletId,
        index: index,
        isChange: isChange,
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
