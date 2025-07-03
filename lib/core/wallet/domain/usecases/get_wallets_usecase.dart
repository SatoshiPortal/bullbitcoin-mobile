import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

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

class GetWalletsException implements Exception {
  final String message;

  GetWalletsException(this.message);
}

class NoWalletsFoundException implements Exception {
  final String message;

  NoWalletsFoundException(this.message);
}
