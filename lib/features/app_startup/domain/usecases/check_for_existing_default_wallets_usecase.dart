import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
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
    final settings = await _settingsRepository.fetch();
    final environment = settings.environment;

    late final List defaultWallets;
    try {
      defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: environment,
      );
    } catch (e) {
      if (e.toString().contains('UpdateOnDifferentStatus')) {
        log.fine('UpdateOnDifferentStatus error, deleting lwkDb');
        await _walletRepository.deleteLwkDb();
        log.fine('Deleted LwkDb, retrying getWallets');
        defaultWallets = await _walletRepository.getWallets(
          onlyDefaults: true,
          environment: environment,
        );
      } else {
        rethrow;
      }
    }

    if (defaultWallets.isNotEmpty) {
      log.fine('FINE: found default wallet');
      // Check all seeds in parallel to avoid sequential keychain reads
      // blocking the UI thread
      await Future.wait(
        defaultWallets.map((wallet) async {
          try {
            await _seedRepository.get(wallet.masterFingerprint);
            log.fine('FINE: Seed Found');
          } catch (e) {
            log.severe(
              message: 'Seed not found for default wallet ',
              error: e,
              trace: StackTrace.current,
            );
            rethrow;
          }
        }),
      );
      return true;
    } else {
      log.fine('No default wallets found');
      return false;
    }
  }
}
