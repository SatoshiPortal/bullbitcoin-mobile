import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';

class CheckForExistingDefaultWalletsUsecase {
  final SettingsRepository _settingsRepository;
  final WalletManagerService _walletManager;

  CheckForExistingDefaultWalletsUsecase({
    required SettingsRepository settingsRepository,
    required WalletManagerService walletManager,
  })  : _settingsRepository = settingsRepository,
        _walletManager = walletManager;

  Future<bool> execute() async {
    // Check if wallets exist for the selected environment
    final environment = await _settingsRepository.getEnvironment();
    return _walletManager.doDefaultWalletsExist(environment: environment);
  }
}
