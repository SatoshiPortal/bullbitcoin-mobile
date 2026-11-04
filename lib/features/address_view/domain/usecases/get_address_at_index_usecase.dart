import 'package:primitives/primitives.dart' show BullException;
import 'package:bb_mobile/features/address_view/public/address_view_facade.dart';

class GetAddressAtIndexUsecase {
  final LabeledWalletAddressRepository _walletAddressRepository;

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
