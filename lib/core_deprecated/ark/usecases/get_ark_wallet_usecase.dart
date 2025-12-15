import 'package:bb_mobile/core_deprecated/ark/entities/ark_wallet.dart';
import 'package:bb_mobile/core_deprecated/ark/errors.dart';
import 'package:bb_mobile/core_deprecated/ark/usecases/fetch_ark_secret_usecase.dart';
import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';

class GetArkWalletUsecase {
  final FetchArkSecretUsecase _fetchArkSecretUsecase;
  final SettingsRepository _settingsRepository;

  GetArkWalletUsecase({
    required FetchArkSecretUsecase fetchArkSecretUsecase,
    required SettingsRepository settingsRepository,
  }) : _fetchArkSecretUsecase = fetchArkSecretUsecase,
       _settingsRepository = settingsRepository;

  Future<ArkWalletEntity?> execute() async {
    try {
      // Ark requires dev mode to be enabled
      final settings = await _settingsRepository.fetch();
      if (settings.isDevModeEnabled != true) return null;

      final arkSecretKey = await _fetchArkSecretUsecase.execute();
      if (arkSecretKey == null) return null;
      return await ArkWalletEntity.init(secretKey: arkSecretKey);
    } catch (e) {
      throw ArkError(e.toString());
    }
  }
}
