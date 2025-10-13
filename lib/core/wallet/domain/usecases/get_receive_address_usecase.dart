import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';

class GetReceiveAddressUsecase {
  final WalletAddressRepository _walletAddressRepository;

  GetReceiveAddressUsecase({
    required WalletAddressRepository walletAddressRepository,
  }) : _walletAddressRepository = walletAddressRepository;

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
        address = await _walletAddressRepository.getLastUnusedReceiveAddress(
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
