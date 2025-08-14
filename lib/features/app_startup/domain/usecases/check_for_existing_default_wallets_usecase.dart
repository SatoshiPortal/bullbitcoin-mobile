import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CheckForExistingDefaultWalletsUsecase {
  final SettingsRepository _settingsRepository;
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;

  CheckForExistingDefaultWalletsUsecase({
    required SettingsRepository settingsRepository,
    required WalletRepository walletRepository,
    required SeedRepository seedRepository,
  }) : _settingsRepository = settingsRepository,
       _walletRepository = walletRepository,
       _seedRepository = seedRepository;

  Future<bool> execute() async {
    // Check if wallets exist for the selected environment
    final settings = await _settingsRepository.fetch();
    final environment = settings.environment;
    final defaultWallets = await _walletRepository.getWallets(
      onlyDefaults: true,
      environment: environment,
    );

    // Check if there are any default wallets
    if (defaultWallets.isNotEmpty) {
      // Check that the seed for the default wallets exist
      for (final wallet in defaultWallets) {
        // This will throw if the seed is not found or can not be decrypted
        await _seedRepository.get(wallet.masterFingerprint);
      }
      return true; // Default wallets and seeds exist
    } else {
      return false; // No default wallets found
    }
  }
}
