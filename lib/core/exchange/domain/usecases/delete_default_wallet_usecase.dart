import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/default_wallets_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class DeleteDefaultWalletUsecase {
  final DefaultWalletsRepository _mainnetRepository;
  final DefaultWalletsRepository _testnetRepository;
  final SettingsRepository _settingsRepository;

  DeleteDefaultWalletUsecase({
    required DefaultWalletsRepository mainnetDefaultWalletsRepository,
    required DefaultWalletsRepository testnetDefaultWalletsRepository,
    required SettingsRepository settingsRepository,
  })  : _mainnetRepository = mainnetDefaultWalletsRepository,
        _testnetRepository = testnetDefaultWalletsRepository,
        _settingsRepository = settingsRepository;

  Future<bool> execute({required String recipientId}) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet ? _testnetRepository : _mainnetRepository;

      return await repo.deleteDefaultWallet(recipientId: recipientId);
    } catch (e) {
      throw DeleteDefaultWalletException('$e');
    }
  }
}

class DeleteDefaultWalletException extends BullException {
  DeleteDefaultWalletException(super.message);
}






