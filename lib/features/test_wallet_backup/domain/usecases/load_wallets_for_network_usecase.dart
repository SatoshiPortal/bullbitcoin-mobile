import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class LoadWalletsForNetworkUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  LoadWalletsForNetworkUsecase({
    required WalletRepository walletRepository,
    required SettingsRepository settingsRepository,
  }) : _walletRepository = walletRepository,
       _settingsRepository = settingsRepository;

  Future<List<Wallet>> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final wallets = await _walletRepository.getWallets(
        onlyDefaults: false,
        onlyBitcoin: true,
        environment: settings.environment,
      );
      return wallets;
    } catch (e) {
      log.severe('LoadWalletsForNetworkUsecase: $e', trace: StackTrace.current);
      rethrow;
    }
  }
}
