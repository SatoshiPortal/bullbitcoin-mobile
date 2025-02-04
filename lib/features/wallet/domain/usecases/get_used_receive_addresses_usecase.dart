import 'package:bb_mobile/features/wallet/domain/entities/address.dart';
import 'package:bb_mobile/features/wallet/domain/services/wallet_repository_manager.dart';

class GetUsedReceiveAddressesUsecase {
  final WalletRepositoryManager _walletRepositoryManager;

  GetUsedReceiveAddressesUsecase({
    required WalletRepositoryManager walletRepositoryManager,
  }) : _walletRepositoryManager = walletRepositoryManager;

  Future<List<Address>> execute({
    required String walletId,
    int? limit,
    int? offset,
  }) async {
    final wallet = _walletRepositoryManager.getRepository(walletId);

    if (wallet == null) {
      return [];
    }

    final addresses = <Address>[];
    return addresses;
  }
}
