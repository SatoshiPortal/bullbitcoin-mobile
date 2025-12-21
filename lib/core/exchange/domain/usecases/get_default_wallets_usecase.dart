import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/entity/default_wallet_address.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/default_wallets_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class GetDefaultWalletsUsecase {
  final DefaultWalletsRepository _mainnetRepository;
  final DefaultWalletsRepository _testnetRepository;
  final SettingsRepository _settingsRepository;

  GetDefaultWalletsUsecase({
    required DefaultWalletsRepository mainnetDefaultWalletsRepository,
    required DefaultWalletsRepository testnetDefaultWalletsRepository,
    required SettingsRepository settingsRepository,
  })  : _mainnetRepository = mainnetDefaultWalletsRepository,
        _testnetRepository = testnetDefaultWalletsRepository,
        _settingsRepository = settingsRepository;

  Future<DefaultWallets> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet ? _testnetRepository : _mainnetRepository;

      return await repo.getDefaultWallets();
    } catch (e) {
      throw GetDefaultWalletsException('$e');
    }
  }
}

class GetDefaultWalletsException extends BullException {
  GetDefaultWalletsException(super.message);
}






