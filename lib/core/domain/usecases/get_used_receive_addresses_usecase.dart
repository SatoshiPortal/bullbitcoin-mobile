import 'package:bb_mobile/core/domain/entities/address.dart';
import 'package:bb_mobile/core/domain/services/wallet_manager.dart';

class GetUsedReceiveAddressesUsecase {
  final WalletManager _walletManager;

  GetUsedReceiveAddressesUsecase({
    required WalletManager walletManager,
  }) : _walletManager = walletManager;

  Future<List<Address>> execute({
    required String walletId,
    int? limit,
    int? offset,
  }) async {
    final wallet = _walletManager.getRepository(walletId);

    if (wallet == null) {
      return [];
    }

    // TODO: move this logic to the repository to get a list of addresses and
    //  use limit and offset to get the desired addresses
    final addresses = <Address>[];
    final lastUnusedAddress = await wallet.getLastUnusedAddress();

    final nrOfAddresses = limit ?? lastUnusedAddress.index ?? 0 - (offset ?? 0);

    for (int i = offset ?? 0; i < nrOfAddresses; i++) {
      final address = await wallet.getAddressByIndex(i);

      addresses.add(address);
    }

    return addresses;
  }
}
