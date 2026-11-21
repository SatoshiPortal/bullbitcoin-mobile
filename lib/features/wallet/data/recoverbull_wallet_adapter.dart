import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:secrets/secrets.dart' show Secrets, KeystoreLockedFailure;

final class RecoverBullWalletAdapter implements RecoverBullWalletPort {
  final WalletRepository _wallets;
  final DeveloperEnvironmentReader _settings;
  final Secrets _secrets;
  final CreateDefaultWalletsUsecase _create;

  const RecoverBullWalletAdapter(
    this._wallets,
    this._settings,
    this._secrets,
    this._create,
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
      switch (await _wallets.getWallets(
        onlyBitcoin: true,
        onlyDefaults: true,
        environment: settings.environment,
      )) {
        case Err():
          return const Err(VaultStorageFailure());
        case Ok(:final value):
          if (value.isEmpty) return const Ok(null);
          if (value.length != 1) return const Err(VaultContextChangedFailure());
          final wallet = value.single;
          if (!wallet.network.isBitcoin ||
              wallet.network.bitcoin.env != settings.environment.networkEnv ||
              !await _stillSelected(settings.environment)) {
            return const Err(VaultContextChangedFailure());
          }
          final description = await _secrets.fetch(
            Fingerprint(wallet.masterFingerprint),
          );
          final bool hasPassphrase;
          switch (description) {
            case Ok(:final value):
              hasPassphrase = value.info.hasPassphrase;
            case Err(failure: KeystoreLockedFailure()):
              return const Err(VaultKeystoreLockedFailure());
            case Err():
              return const Err(VaultStorageFailure());
          }
          return Ok(
            VaultContext(
              fingerprint: Fingerprint(wallet.masterFingerprint),
              hasPassphrase: hasPassphrase,
              network: wallet.network.bitcoin,
            ),
          );
      }
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
          final result = await _create.execute(
            secret: value,
            expectedNetwork: requested.network.env,
          );
          if (result case Err()) return const Err(VaultStorageFailure());
          final created = switch (result) {
            Ok(:final value) => value,
            Err() => const <Never>[],
          };
          final bitcoin = created
              .where((wallet) => wallet.network.isBitcoin)
              .toList();
          if (bitcoin.length != 1) {
            return const Err(VaultContextChangedFailure());
          }
          final wallet = bitcoin.single;
          // Return the actual committed context. The feature compares it with
          // the request and never certifies a different network or fingerprint.
          return Ok(
            VaultContext(
              fingerprint: Fingerprint(wallet.masterFingerprint),
              network: wallet.network.bitcoin,
            ),
          );
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
