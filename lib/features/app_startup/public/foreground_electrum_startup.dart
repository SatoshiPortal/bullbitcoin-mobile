import 'package:bb_mobile/features/settings/public/settings_bootstrap.dart';
import 'package:primitives/primitives.dart';

/// PR1's passive storage barrier. Consumes the snapshot already normalized by
/// Settings; composition supplies Electrum's public preparation method.
final class ForegroundElectrumStartup {
  static Future<void> prepare({
    required SettingsEntity capturedSettings,
    required Future<bool> Function(NetworkEnv) prepareElectrum,
  }) async {
    final selected = SettingsBootstrap.captureAuthorizedEnvironment(
      capturedSettings,
    );
    final NetworkEnv environment;
    switch (selected) {
      case Err():
        throw const ForegroundElectrumPreparationException();
      case Ok(:final value):
        environment = value;
    }
    if (!await prepareElectrum(environment)) {
      throw const ForegroundElectrumPreparationException();
    }
  }
}

final class ForegroundElectrumPreparationException implements Exception {
  const ForegroundElectrumPreparationException();
}
