import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';

class SetPayjoinExpireAfterSecUsecase {
  final SettingsRepository _settingsRepository;

  SetPayjoinExpireAfterSecUsecase({required this._settingsRepository});

  /// Enforces [PayjoinConstants.minExpireAfterSec]/[maxExpireAfterSec] here,
  /// not just in the settings screen's input validator — see
  /// SetPayjoinMinAmountUsecase's doc comment for why.
  Future<void> execute(int expireAfterSec) async {
    if (expireAfterSec < PayjoinConstants.minExpireAfterSec ||
        expireAfterSec > PayjoinConstants.maxExpireAfterSec) {
      throw ArgumentError.value(
        expireAfterSec,
        'expireAfterSec',
        'Must be between ${PayjoinConstants.minExpireAfterSec} and '
            '${PayjoinConstants.maxExpireAfterSec} seconds',
      );
    }
    await _settingsRepository.setPayjoinExpireAfterSec(expireAfterSec);
  }
}
