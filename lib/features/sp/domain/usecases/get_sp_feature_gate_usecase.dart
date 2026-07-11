import 'package:bb_mobile/core/settings/data/settings_repository.dart';

/// The Silent Payments feature is gated behind superuser + dev mode. Thin read
/// so callers (the wallet bloc) get the boolean gate through a use case seam
/// instead of touching `SettingsRepository` directly.
class GetSpFeatureGateUsecase {
  final SettingsRepository _settingsRepository;

  GetSpFeatureGateUsecase({required this._settingsRepository});

  Future<bool> execute() async {
    final settings = await _settingsRepository.fetch();
    return (settings.isSuperuser ?? false) &&
        (settings.isDevModeEnabled ?? false);
  }
}
