import 'package:primitives/primitives.dart';

import '../domain/settings_entity.dart';
import '../domain/settings_failure.dart';

export '../domain/settings_entity.dart' show SettingsEntity;
export '../domain/settings_failure.dart';

/// Validates the normalized snapshot already read by foreground composition.
/// No second SQL read and no session/admission rollout dependency.
final class SettingsBootstrap {
  static Result<NetworkEnv, SettingsFailure> captureAuthorizedEnvironment(
    SettingsEntity selected,
  ) {
    final environment = selected.environment.networkEnv;
    if (environment != NetworkEnv.mainnet &&
        (selected.isSuperuser != true || selected.isDevModeEnabled != true)) {
      return const Err(SettingsConsentFailure());
    }
    return Ok(environment);
  }
}
