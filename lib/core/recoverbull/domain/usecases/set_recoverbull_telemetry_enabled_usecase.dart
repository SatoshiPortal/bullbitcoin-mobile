import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

/// Enables or disables the brute-force telemetry checks.
///
/// The flag is a rollout gate, not a user preference: it stays false until the
/// deployed server contract and the pinned client are confirmed in production.
/// The toggle is surfaced behind dev mode so QA can exercise the feature
/// before that.
class SetRecoverbullTelemetryEnabledUsecase {
  final SettingsRepository settingsRepository;

  SetRecoverbullTelemetryEnabledUsecase({required this.settingsRepository});

  Future<void> execute(bool isEnabled) {
    return settingsRepository.setIsRecoverbullTelemetryEnabled(isEnabled);
  }
}
