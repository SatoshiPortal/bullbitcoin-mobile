import 'package:bb_mobile/core/ark/usecases/fetch_ark_secret_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class CheckArkWalletSetupUsecase {
  final FetchArkSecretUsecase _fetchArkSecretUsecase;
  final SettingsRepository _settingsRepository;

  CheckArkWalletSetupUsecase({
    required this._fetchArkSecretUsecase,
    required this._settingsRepository,
  });

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
