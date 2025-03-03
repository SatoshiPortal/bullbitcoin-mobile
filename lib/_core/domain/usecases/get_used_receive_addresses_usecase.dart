import 'package:bb_mobile/_core/domain/entities/address.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_manager_repository.dart';

class GetUsedReceiveAddressesUsecase {
  final WalletManagerRepository _walletManager;

  GetUsedReceiveAddressesUsecase({
    required WalletManagerRepository walletManager,
  }) : _walletManager = walletManager;

  Future<List<Address>> execute({
    required String walletId,
    int? limit,
    int? offset,
  }) async {
    final addresses = _walletManager.getUsedReceiveAddresses(
      walletId: walletId,
      limit: limit,
      offset: offset,
    );

    return addresses;
  }
}
