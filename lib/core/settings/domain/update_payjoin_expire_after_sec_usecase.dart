import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

/// Persists the payjoin session lifetime (seconds), shared by both the
/// receive and send sides. See PayjoinConstants.minExpireAfterSec/
/// maxExpireAfterSec for the accepted bounds.
class UpdatePayjoinExpireAfterSecUsecase {
  final SettingsRepository _settingsRepository;

  UpdatePayjoinExpireAfterSecUsecase({required this._settingsRepository});

  Future<void> execute({required int payjoinExpireAfterSec}) async {
    await _settingsRepository.setPayjoinExpireAfterSec(payjoinExpireAfterSec);
  }
}
