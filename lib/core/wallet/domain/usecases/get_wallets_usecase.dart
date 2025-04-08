import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class GetWalletsUsecase {
  final WalletRepository _wallet;
  final SettingsRepository _settingsRepository;

  GetWalletsUsecase({
    required WalletRepository walletRepository,
    required SettingsRepository settingsRepository,
  })  : _wallet = walletRepository,
        _settingsRepository = settingsRepository;

  Future<List<Wallet>> execute({
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
    bool sync = false,
  }) async {
    try {
      final environment = await _settingsRepository.getEnvironment();

      final wallets = await _wallet.getWallets(
        environment: environment,
        onlyDefaults: onlyDefaults,
        onlyBitcoin: onlyBitcoin,
        onlyLiquid: onlyLiquid,
        sync: sync,
      );

      if (wallets.isEmpty) {
        throw Exception('No wallets found');
      }

      return wallets;
    } catch (e) {
      throw GetWalletsException('$e');
    }
  }
}

class GetWalletsException implements Exception {
  final String message;

  GetWalletsException(this.message);
}
