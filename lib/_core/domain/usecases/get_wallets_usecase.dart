import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';

class GetWalletsUsecase {
  final WalletManagerService _manager;
  final SettingsRepository _settingsRepository;

  GetWalletsUsecase({
    required WalletManagerService walletManager,
    required SettingsRepository settingsRepository,
  })  : _manager = walletManager,
        _settingsRepository = settingsRepository;

  Future<List<Wallet>> execute() async {
    final environment = await _settingsRepository.getEnvironment();
    final wallets = await _manager.getAllWallets(environment: environment);
    return wallets;
  }
}
