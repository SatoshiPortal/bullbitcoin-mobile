import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class CheckForExistingDefaultWalletsUsecase {
  final SettingsRepository _settingsRepository;
  final WalletRepository _walletRepository;

  CheckForExistingDefaultWalletsUsecase({
    required SettingsRepository settingsRepository,
    required WalletRepository walletRepository,
  })  : _settingsRepository = settingsRepository,
        _walletRepository = walletRepository;

  Future<bool> execute() async {
    // Check if wallets exist for the selected environment
    final environment = await _settingsRepository.getEnvironment();
    final defaultWallets = await _walletRepository.getWallets(
      onlyDefaults: true,
      environment: environment,
    );

    // Check if there are any default wallets
    if (defaultWallets.isNotEmpty) {
      return true; // Default wallets exist
    } else {
      return false; // No default wallets found
    }
  }
}
