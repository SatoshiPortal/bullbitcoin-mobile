import 'package:preferences/preferences.dart';
import 'package:bull_tor/tor.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart' show RecoverBullFailure;
import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';

/// Eagerly warms the configured Tor route for an existing RecoverBull backup.
class InitializeRequiredTorUsecase {
  final Future<Result<bool, RecoverBullFailure>> Function() _hasEncryptedBackup;
  final Preferences _settingsRepository;
  final Tor _tor;

  const InitializeRequiredTorUsecase(
    this._hasEncryptedBackup,
    this._settingsRepository,
    this._tor,
  );

  Future<TorConnectionState?> execute() async {
    switch (await _hasEncryptedBackup()) {
      case Ok(value: true):
        break;
      case Ok():
        return null;
      // Same as before this check returned a Result: an unknown answer skips
      // Tor rather than starting it. Logged, type only.
      case Err(:final failure):
        log.warning(
          'Encrypted backup check failed, skipping Tor: ${failure.runtimeType}',
        );
        return null;
    }
    final settings = (await _settingsRepository.fetch()).fold(
      (value) => value,
      (failure) => throw Exception('Preferences read failed'),
    );
    return _tor.warmUp(
      externalProxyPort: settings.useTorProxy ? settings.torProxyPort : null,
    );
  }
}
