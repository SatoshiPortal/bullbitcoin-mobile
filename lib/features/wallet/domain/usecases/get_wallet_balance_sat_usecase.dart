import 'package:bb_mobile/features/wallet/domain/entities/balance.dart';
import 'package:bb_mobile/features/wallet/domain/services/wallet_repository_manager.dart';

class GetWalletBalanceSatUseCase {
  final WalletRepositoryManager _manager;

  GetWalletBalanceSatUseCase(
      {required WalletRepositoryManager walletRepositoryManager})
      : _manager = walletRepositoryManager;

  Future<Balance> execute(String walletId) async {
    final walletRepository = _manager.getRepository(walletId);

    if (walletRepository == null) {
      return Balance(
        immatureSat: BigInt.zero,
        trustedPendingSat: BigInt.zero,
        untrustedPendingSat: BigInt.zero,
        confirmedSat: BigInt.zero,
        spendableSat: BigInt.zero,
        totalSat: BigInt.zero,
      );
    }

    return await walletRepository.getBalance();
  }
}
