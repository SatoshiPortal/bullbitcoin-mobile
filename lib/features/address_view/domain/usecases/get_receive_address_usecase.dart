import 'package:primitives/primitives.dart' show BullException;
import 'package:bb_mobile/features/address_view/public/address_view_facade.dart';

class GetReceiveAddressUsecase {
  final LabeledWalletAddressRepository _walletAddressRepository;

  GetReceiveAddressUsecase({required this._walletAddressRepository});

  Future<WalletAddress> execute({
    required String walletId,
    bool generateNew = false,
  }) async {
    try {
      WalletAddress address;
      if (generateNew) {
        address = await _walletAddressRepository.generateNewReceiveAddress(
          walletId: walletId,
        );
      } else {
        address = await _walletAddressRepository.getLastRevealedReceiveAddress(
          walletId: walletId,
        );
      }

      return address;
    } catch (e) {
      throw GetReceiveAddressException(e.toString());
    }
  }
}

class GetReceiveAddressException extends BullException {
  GetReceiveAddressException(super.message);
}
