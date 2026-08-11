import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

/// Whether brute-force telemetry checks (`/attempts` polling and
/// suspicious-activity warnings) are enabled. Disabled by default: the
/// feature rolls out only after the server contract and the pinned client
/// are confirmed in production.
class IsRecoverbullTelemetryEnabledUsecase {
  final SettingsRepository settingsRepository;

  IsRecoverbullTelemetryEnabledUsecase({required this.settingsRepository});

  Future<bool> execute() {
    return settingsRepository.fetchIsRecoverbullTelemetryEnabled();
  }
}
