import 'package:bb_mobile/core_deprecated/ark/usecases/fetch_ark_secret_usecase.dart';
import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';

class CheckArkWalletSetupUsecase {
  final FetchArkSecretUsecase _fetchArkSecretUsecase;
  final SettingsRepository _settingsRepository;

  CheckArkWalletSetupUsecase({
    required FetchArkSecretUsecase fetchArkSecretUsecase,
    required SettingsRepository settingsRepository,
  }) : _fetchArkSecretUsecase = fetchArkSecretUsecase,
       _settingsRepository = settingsRepository;

  Future<bool> execute() async {
    try {
      // Ark requires dev mode to be enabled
      final settings = await _settingsRepository.fetch();
      if (settings.isDevModeEnabled != true) return false;

      final arkSecretKey = await _fetchArkSecretUsecase.execute();
      return arkSecretKey != null;
    } catch (e) {
      return false;
    }
  }
}
