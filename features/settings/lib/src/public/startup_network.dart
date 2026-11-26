import 'package:electrum/setup.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show SecretEntry, SecretFailure;
import 'package:settings/src/domain/settings_failure.dart';
import 'package:settings/src/domain/usecases/set_active_network_usecase.dart';
import 'package:settings/src/domain/usecases/set_is_dev_mode_usecase.dart';
import 'package:settings/src/domain/usecases/set_is_superuser_usecase.dart';

/// Applies an explicitly unlocked and confirmed first-run choice.
final class StartupNetwork {
  const StartupNetwork._();

  static Future<Result<void, SettingsFailure>> apply({
    required Preferences preferences,
    required ElectrumDefaultsProvisioner electrum,
    required NetworkEnv network,
    required bool superuserUnlocked,
    required bool developerConsent,
    required Future<Result<bool, SecretFailure>> Function() isProtected,
    required Future<Result<bool, SecretFailure>> Function() hasWallets,
    required Future<Result<List<SecretEntry>, SecretFailure>> Function()
    listSecrets,
  }) async {
    if (!superuserUnlocked || !developerConsent) {
      return const Err(SettingsConsentFailure());
    }
    if (network != NetworkEnv.testnet &&
        (network != NetworkEnv.regtest || !RegtestHostProfile.isConfigured)) {
      return Err(SettingsNetworkUnavailableFailure(network));
    }
    final protected = await isProtected();
    if (protected is! Ok<bool, SecretFailure> || protected.value) {
      return const Err(SettingsStorageFailure());
    }
    final wallets = await hasWallets();
    if (wallets is! Ok<bool, SecretFailure> || wallets.value) {
      return const Err(SettingsStorageFailure());
    }
    final secrets = await listSecrets();
    if (secrets is! Ok<List<SecretEntry>, SecretFailure> ||
        secrets.value.isNotEmpty) {
      return const Err(SettingsStorageFailure());
    }
    final superuser = await SetIsSuperuserUsecase(
      settingsRepository: preferences,
    ).execute(true);
    if (superuser case Err(:final failure)) return Err(failure);
    final developer = await SetIsDevModeUsecase(settingsRepository: preferences)
        .execute(true);
    if (developer case Err(:final failure)) return Err(failure);
    return SetActiveNetworkUsecase(
      settingsRepository: preferences,
      electrumSettings: electrum,
    ).execute(network);
  }
}
