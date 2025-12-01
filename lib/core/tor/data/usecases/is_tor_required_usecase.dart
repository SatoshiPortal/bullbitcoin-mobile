import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class IsTorRequiredUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  IsTorRequiredUsecase({
    required WalletRepository walletRepository,
    required SettingsRepository settingsRepository,
  }) : _walletRepository = walletRepository,
       _settingsRepository = settingsRepository;

  Future<bool> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final useTorProxy = settings.useTorProxy;

      if (useTorProxy) {
        log.config('Tor Proxy already enabled, do not init Recoverbull Tor');
        return false;
      } else {
        return await _walletRepository.isTorRequired();
      }
    } catch (e) {
      log.severe('$IsTorRequiredUsecase: $e');
      return false;
    }
  }
}
