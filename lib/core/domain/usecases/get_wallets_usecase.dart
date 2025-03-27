import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_manager_service.dart';

class GetWalletsUsecase {
  final WalletManagerService _manager;
  final SettingsRepository _settingsRepository;

  GetWalletsUsecase({
    required WalletManagerService walletManager,
    required SettingsRepository settingsRepository,
  })  : _manager = walletManager,
        _settingsRepository = settingsRepository;

  Future<List<Wallet>> execute({
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
  }) async {
    try {
      final environment = await _settingsRepository.getEnvironment();
      final wallets = await _manager.getWallets(
        environment: environment,
        onlyDefaults: onlyDefaults,
        onlyBitcoin: onlyBitcoin,
        onlyLiquid: onlyLiquid,
      );

      if (wallets.isEmpty) {
        throw GetWalletsException('No wallets found');
      }

      return wallets;
    } catch (e) {
      if (e is GetWalletsException) {
        rethrow;
      }

      throw GetWalletsException('$e');
    }
  }
}

class GetWalletsException implements Exception {
  final String message;

  GetWalletsException(this.message);
}
