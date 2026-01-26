import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class GetDefaultSeedUsecase {
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;

  GetDefaultSeedUsecase({
    required WalletRepository walletRepository,
    required SeedRepository seedRepository,
  }) : _walletRepository = walletRepository,
       _seedRepository = seedRepository;

  Future<Seed> execute() async {
    try {
      final wallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
      );
      if (wallets.isEmpty) throw 'No default wallet found';
      final defaultWallet = wallets.first;
      return await _seedRepository.get(defaultWallet.masterFingerprint);
    } catch (e) {
      log.severe('$GetDefaultSeedUsecase: $e', trace: StackTrace.current);
      rethrow;
    }
  }
}
