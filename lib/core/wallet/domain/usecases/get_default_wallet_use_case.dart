

import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';

class GetDefaultWalletUsecase {
  final WalletManagerService _manager;
  final SettingsRepository _settingsRepository;

  GetDefaultWalletUsecase({
    required WalletManagerService walletManager,
    required SettingsRepository settingsRepository,
  })  : _manager = walletManager,
        _settingsRepository = settingsRepository;

  Future<Wallet> execute() async {
    final environment = await _settingsRepository.getEnvironment();
    final wallets = await _manager.getWallets(
      environment: environment,
      onlyDefaults: true,
      onlyBitcoin: true,
    );
    return wallets.first;
  }
}
