import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';

class GetNewReceiveAddressUsecase {
  final WalletAddressRepository _walletAddressRepository;

  GetNewReceiveAddressUsecase({
    required WalletAddressRepository walletAddressRepository,
  }) : _walletAddressRepository = walletAddressRepository;

  Future<WalletAddress> execute({
    required String walletId,
    bool forceUnseenLiquidAddress = false,
  }) async {
    try {
      final address = await _walletAddressRepository.getNewReceiveAddress(
        walletId: walletId,
        forceUnseenLiquidAddress: forceUnseenLiquidAddress,
      );

      return address;
    } catch (e) {
      throw GetNewReceiveAddressException(e.toString());
    }
  }
}

class GetNewReceiveAddressException implements Exception {
  final String? message;

  GetNewReceiveAddressException(this.message);
}
