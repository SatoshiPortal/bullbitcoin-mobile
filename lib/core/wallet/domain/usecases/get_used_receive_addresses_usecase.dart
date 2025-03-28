

import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';

class GetUsedReceiveAddressesUsecase {
  final WalletManagerService _walletManager;

  GetUsedReceiveAddressesUsecase({
    required WalletManagerService walletManager,
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
