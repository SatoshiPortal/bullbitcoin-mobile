import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bull_logger/bull_logger.dart';

class GetDefaultSeedUsecase {
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;

  GetDefaultSeedUsecase({
    required this._walletRepository,
    required this._seedRepository,
  });

  Future<Seed> execute({required Environment environment}) async {
    try {
      final wallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: environment,
      );
      if (wallets.isEmpty) throw 'No default wallet found';
      final defaultWallet = wallets.first;
      return await _seedRepository.get(defaultWallet.masterFingerprint);
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      rethrow;
    }
  }
}
