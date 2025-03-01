import 'package:bb_mobile/_core/domain/entities/balance.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager.dart';

class GetWalletBalanceSatUseCase {
  final WalletManager _manager;

  GetWalletBalanceSatUseCase({required WalletManager walletManager})
      : _manager = walletManager;

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
