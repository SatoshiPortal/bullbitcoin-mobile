import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet.dart';

class GetWalletsUsecase {
  final WalletRepository _wallet;
  final SettingsRepository _settingsRepository;

  GetWalletsUsecase({
    required WalletRepository walletRepository,
    required SettingsRepository settingsRepository,
  }) : _wallet = walletRepository,
       _settingsRepository = settingsRepository;

  Future<List<Wallet>> execute({
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
    bool sync = false,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final wallets = await _wallet.getWallets(
        environment: environment,
        onlyDefaults: onlyDefaults,
        onlyBitcoin: onlyBitcoin,
        onlyLiquid: onlyLiquid,
        sync: sync,
      );

      if (wallets.isEmpty) {
        throw NoWalletsFoundException(
          "No wallets found for the current environment: $environment",
        );
      }

      return wallets;
    } on NoWalletsFoundException {
      rethrow;
    } catch (e) {
      throw GetWalletsException('$e');
    }
  }
}

class GetWalletsException extends BullException {
  GetWalletsException(super.message);
}

class NoWalletsFoundException extends BullException {
  NoWalletsFoundException(super.message);
}
