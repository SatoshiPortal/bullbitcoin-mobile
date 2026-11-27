import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart' show DeveloperEnvironmentReader;
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import 'default_wallets.dart';
import 'provisioning_failure.dart';
import 'src/default_wallet_secret_policy.dart';

/// What a developer network offers when its default wallets are missing.
final class NetworkWalletSetup {
  final NetworkEnv network;
  final List<Fingerprint> reusable;

  const NetworkWalletSetup(this.network, this.reusable);
}

/// Sets up the default wallets of a developer network, from a generated
/// secret or from one already referenced by the catalog.
///
/// Every request revalidates the network, the developer rights, the catalog
/// reference and the kind of the secret. A secret is never deleted on failure.
final class NetworkWalletProvisioning {
  final DeveloperEnvironmentReader _settings;
  final WalletInventory _inventory;
  final DefaultWalletProvisioning _defaults;
  final Secrets? _secrets;

  /// Without [secrets], setup can still generate, but offers no reference for
  /// reuse and refuses one.
  const NetworkWalletProvisioning({
    required this._settings,
    required this._inventory,
    required this._defaults,
    this._secrets,
  });

  @useResult
  Future<Result<NetworkWalletSetup, NetworkWalletSetupFailure>> load() async {
    try {
      final settings = (await _settings.readDeveloperEnvironment()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      final network = settings.environment.networkEnv;
      if (network == NetworkEnv.mainnet) {
        return const Ok(NetworkWalletSetup(NetworkEnv.mainnet, []));
      }
      if (settings.isDevModeEnabled != true || settings.isSuperuser != true) {
        log.warning('Network wallet setup refused category=developerMode');
        return const Err(NetworkWalletSetupContextFailure());
      }
      final secrets = _secrets;
      // Without custody capability, setup can still generate or import, but
      // cannot offer an unchecked reference for reuse.
      if (secrets == null) return Ok(NetworkWalletSetup(network, const []));
      final references = await _inventory.referencedFingerprints();
      if (references case Err()) {
        return const Err(NetworkWalletSetupStorageFailure());
      }
      final reusable = <Fingerprint>[];
      if (references case Ok(:final value)) {
        for (final fingerprint in value) {
          switch (await secrets.fetch(fingerprint)) {
            case Ok(:final value):
              if (defaultWalletSecretRefusal(value.info) == null) {
                reusable.add(fingerprint);
              }
            case Err(failure: SecretNotFoundFailure()):
              // Public descriptors can reference secrets held outside the app.
              continue;
            case Err():
              return const Err(NetworkWalletSetupUnavailableFailure());
          }
        }
      }
      return Ok(NetworkWalletSetup(network, reusable));
    } on Exception {
      log.warning('Network wallet setup unavailable category=settingsRead');
      return const Err(NetworkWalletSetupUnavailableFailure());
    }
  }

  /// Provision from an existing handle or generate via the existing resumable
  /// default-wallet flow. Never delete a secret on failure.
  @useResult
  Future<Result<void, NetworkWalletSetupFailure>> create({
    required NetworkEnv network,
    Fingerprint? reuse,
  }) async {
    try {
      final settings = (await _settings.readDeveloperEnvironment()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      if (network == NetworkEnv.mainnet ||
          network == NetworkEnv.signet ||
          settings.environment.networkEnv != network ||
          settings.isDevModeEnabled != true ||
          settings.isSuperuser != true) {
        log.warning('Network wallet setup refused category=context');
        return const Err(NetworkWalletSetupContextFailure());
      }
      Secret? secret;
      if (reuse != null) {
        switch (await _inventory.referencedFingerprints()) {
          case Err():
            return const Err(NetworkWalletSetupStorageFailure());
          case Ok(:final value) when !value.contains(reuse):
            return const Err(NetworkWalletSetupReferenceNotFoundFailure());
          case Ok():
            break;
        }
        final secrets = _secrets;
        if (secrets == null) {
          return const Err(NetworkWalletSetupUnavailableFailure());
        }
        switch (await secrets.fetch(reuse)) {
          case Err():
            return const Err(NetworkWalletSetupUnavailableFailure());
          case Ok(:final value):
            secret = value;
        }
        final refusal = defaultWalletSecretRefusal(secret.info);
        if (refusal != null) {
          log.warning('Network wallet setup refused category=secretKind');
          return Err(NetworkWalletSetupSecretFailure(refusal));
        }
      }
      switch (await _defaults.execute(
        secret: secret,
        expectedNetwork: network,
      )) {
        case Err(failure: DefaultWalletBackupRequiredFailure()):
          return const Err(NetworkWalletSetupBackupRequiredFailure());
        case Err():
          return const Err(NetworkWalletSetupUnavailableFailure());
        case Ok():
          break;
      }
      log.fine(
        'Network wallet setup completed network=${network.name} reused=${reuse != null}',
      );
      return const Ok(null);
    } on Exception {
      log.warning('Network wallet setup unavailable category=provisioning');
      return const Err(NetworkWalletSetupUnavailableFailure());
    }
  }
}
