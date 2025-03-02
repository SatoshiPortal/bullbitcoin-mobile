import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_manager_repository.dart';

class CheckForExistingDefaultWalletsUseCase {
  final SettingsRepository _settingsRepository;
  final WalletManagerRepository _walletManager;

  CheckForExistingDefaultWalletsUseCase({
    required SettingsRepository settingsRepository,
    required WalletManagerRepository walletManager,
  })  : _settingsRepository = settingsRepository,
        _walletManager = walletManager;

  Future<bool> execute() async {
    // Check if wallets exist for the selected environment
    final environment = await _settingsRepository.getEnvironment();
    return _walletManager.doDefaultWalletsExist(environment: environment);
  }
}
