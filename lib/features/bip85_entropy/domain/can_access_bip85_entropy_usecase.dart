import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';

/// Defense-in-depth guard for the developer entropy screen.
class CanAccessBip85EntropyUsecase {
  final GetSettingsUsecase _getSettings;

  const CanAccessBip85EntropyUsecase({required this._getSettings});

  Future<bool> execute() async {
    try {
      final settings = await _getSettings.execute();
      return settings.isSuperuser == true && settings.isDevModeEnabled == true;
    } catch (error, trace) {
      log.warning(
        'Could not evaluate BIP85 entropy access',
        error: error.runtimeType,
        trace: trace,
      );
      return false;
    }
  }
}
