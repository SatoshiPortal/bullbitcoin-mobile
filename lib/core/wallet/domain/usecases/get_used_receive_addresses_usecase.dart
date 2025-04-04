import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class GetUsedReceiveAddressesUsecase {
  final WalletManagerService _walletManager;

  GetUsedReceiveAddressesUsecase({
    required WalletRepository walletRepository,
  }) : _walletManager = walletManager;

  Future<List<Address>> execute({
    required String walletId,
    int? limit,
    int? offset,
  }) {
    final addresses = _walletManager.getUsedReceiveAddresses(
      walletId: walletId,
      limit: limit,
      offset: offset,
    );

    return addresses;
  }
}
