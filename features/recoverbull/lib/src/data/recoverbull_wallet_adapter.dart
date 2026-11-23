import 'package:bull_logger/bull_logger.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import '../domain/entities/vault_context.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/recoverbull_wallet_port.dart';

/// Provisions the default accounts and returns the identity actually committed.
typedef RestoreDefaultAccounts =
    Future<Result<VaultContext, RecoverBullFailure>> Function(
      Secret secret,
      BitcoinNetwork network,
    );

final class RecoverBullWalletAdapter implements RecoverBullWalletPort {
  final WalletInventory _wallets;
  final DeveloperEnvironmentReader _settings;
  final Secrets _secrets;
  final RestoreDefaultAccounts _restore;

  const RecoverBullWalletAdapter(
    this._wallets,
    this._settings,
    this._secrets,
    this._restore,
  );

  @override
  Future<Result<VaultContext?, RecoverBullFailure>> currentDefault() async {
    try {
      final settings = (await _settings.readDeveloperEnvironment()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      if (!_authorized(settings)) {
        return const Err(VaultContextChangedFailure());
      }
      final network = BitcoinNetwork.fromName(settings.environment.name);
      final result = await _wallets.walletsForNetwork(network);
      if (result case Err()) return const Err(VaultStorageFailure());
      final selection = (result as Ok<WalletSelection, SecretFailure>).value;
      if (!selection.isComplete) return const Err(VaultStorageFailure());
      if (!await _stillSelected(settings.environment)) {
        return const Err(VaultContextChangedFailure());
      }
      if (selection.defaults.isEmpty) return const Ok(null);
      final wallet = selection.defaultWallet;
      final fingerprint = wallet?.secretFingerprint;
      if (wallet == null ||
          wallet.signer != WalletSigner.local ||
          fingerprint == null ||
          wallet.masterFingerprint != fingerprint) {
        return const Err(VaultContextChangedFailure());
      }
      final description = await _secrets.fetch(fingerprint);
      return switch (description) {
        Ok(:final value) => Ok(
          VaultContext(
            fingerprint: fingerprint,
            hasPassphrase: value.info.hasPassphrase,
            network: network,
          ),
        ),
        Err(failure: KeystoreLockedFailure()) => const Err(
          VaultKeystoreLockedFailure(),
        ),
        Err() => const Err(VaultStorageFailure()),
      };
    } on Exception {
      log.warning('recoverbull.wallet.read.failed');
      return const Err(VaultStorageFailure());
    }
  }

  @override
  Future<Result<VaultContext, RecoverBullFailure>> restoreDefaults(
    VaultContext requested,
  ) async {
    try {
      if (requested.network == BitcoinNetwork.signet) {
        return const Err(VaultContextChangedFailure());
      }
      final settings = (await _settings.readDeveloperEnvironment()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      if (!_authorized(settings) ||
          settings.environment.networkEnv != requested.network.env) {
        return const Err(VaultContextChangedFailure());
      }
      final fetched = await _secrets.fetch(requested.fingerprint);
      switch (fetched) {
        case Err(failure: KeystoreLockedFailure()):
          return const Err(VaultKeystoreLockedFailure());
        case Err():
          return const Err(VaultStorageFailure());
        case Ok(:final value):
          if (!await _stillSelected(settings.environment)) {
            return const Err(VaultContextChangedFailure());
          }
          return await _restore(value, requested.network);
      }
    } on Exception {
      log.warning('recoverbull.wallet.restore.failed');
      return const Err(VaultStorageFailure());
    }
  }

  bool _authorized(DeveloperEnvironmentPreferences settings) =>
      settings.environment != Environment.regtest ||
      (settings.isSuperuser == true && settings.isDevModeEnabled == true);

  Future<bool> _stillSelected(Environment expected) async {
    final settings = (await _settings.readDeveloperEnvironment()).fold(
      (value) => value,
      (failure) => throw Exception('Preferences read failed'),
    );
    return settings.environment == expected && _authorized(settings);
  }
}
