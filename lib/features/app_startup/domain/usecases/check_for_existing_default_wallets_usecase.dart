import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart'
    show Err, Fingerprint, NetworkCapabilities, NetworkCapability, Ok, Result;
import 'package:secrets/secrets.dart';

class CheckForExistingDefaultWalletsUsecase {
  final SettingsRepository _settingsRepository;
  final WalletRepository _walletRepository;
  final Secrets _secrets;

  CheckForExistingDefaultWalletsUsecase({
    required this._settingsRepository,
    required this._walletRepository,
    required this._secrets,
  });

  @useResult
  Future<Result<bool, AppStartupFailure>> execute() async {
    try {
      return await _check();
    } on KeychainLockedException {
      return const Err(AppStartupKeychainLockedFailure());
    } on Object catch (e, st) {
      log.severe(
        message: 'Default wallet check failed at startup',
        error: e,
        trace: st,
      );
      return const Err(AppStartupWalletCheckFailure());
    }
  }

  Future<Result<bool, AppStartupFailure>> _check() async {
    final settings = await _settingsRepository.fetch();
    final environment = settings.environment;

    List<Wallet> defaultWallets;
    switch (await _walletRepository.getWallets(
      onlyDefaults: true,
      environment: environment,
    )) {
      case Ok(:final value):
        defaultWallets = value;
      case Err(:final failure):
        return Err(_walletCheckFailed(failure));
    }

    if (defaultWallets.isEmpty) {
      // An empty developer network is not a fresh installation. Preserve
      // app protection and route to the network-wallet setup on the home page.
      return switch (await _walletRepository.hasStoredWallets()) {
        Ok(:final value) => Ok(value),
        Err(:final failure) => Err(_walletCheckFailed(failure)),
      };
    }

    final hasBitcoin = defaultWallets.any((w) => w.network.isBitcoin);
    final hasLiquid = defaultWallets.any((w) => w.network.isLiquid);
    final liquidNetwork = Network.fromEnvironment(
      environment: environment.networkEnv,
      isLiquid: true,
    );
    final needsLiquid = NetworkCapabilities.supports(
      liquidNetwork.shared,
      NetworkCapability.softwareWallet,
    );
    if (!hasBitcoin || (needsLiquid && !hasLiquid)) {
      final missing = !hasBitcoin ? 'bitcoin' : 'liquid';
      log.severe(
        message: 'CheckForExistingDefaultWalletsUsecase: partial default set at cold start',
        error: StateError('missing $missing default wallet'),
        trace: StackTrace.current,
      );
      try {
        final secret = switch (await _secrets.fetch(
          Fingerprint(defaultWallets.first.masterFingerprint),
        )) {
          Ok(:final value) => value,
          Err(:final failure) => throw StateError(
            'default secret unavailable: ${failure.runtimeType}',
          ),
        };
        final network = Network.fromEnvironment(
          environment: environment.networkEnv,
          isLiquid: hasBitcoin,
        );
        await _walletRepository.createWallet(
          secret: secret,
          network: network,
          scriptType: ScriptType.bip84,
          isDefault: true,
        );
        // Best effort, like the rest of the heal: a failed re-read keeps the
        // wallets already found, and the seed check below still runs.
        switch (await _walletRepository.getWallets(
          onlyDefaults: true,
          environment: environment,
        )) {
          case Ok(:final value):
            defaultWallets = value;
          case Err(:final failure):
            log.warning(
              'Default wallets re-read after heal failed: '
              '${failure.runtimeType}',
            );
        }
      } catch (e, stackTrace) {
        log.severe(
          message: 'CheckForExistingDefaultWalletsUsecase: legacy heal failed',
          error: e,
          trace: stackTrace,
        );
      }
    }

    log.fine('FINE: found default wallet');
    // Three outcomes, three remedies — which is the whole reason the package
    // refuses to collapse them. A locked keystore is transient and the app
    // waits for unlock; a genuine absence means the seed is gone while its
    // wallet metadata is not; anything else is a read that failed, and
    // treating that as an absence would be offering to replace a seed that
    // is still there.
    for (final wallet in defaultWallets) {
      switch (await _secrets.fetch(Fingerprint(wallet.masterFingerprint))) {
        case Ok():
          log.fine('FINE: Seed Found');
        case Err(failure: KeystoreLockedFailure()):
          log.warning(
            'Keystore locked while checking default wallet; '
            'waiting for unlock',
          );
          return const Err(AppStartupKeychainLockedFailure());
        case Err(failure: SecretNotFoundFailure()):
          log.severe(
            message: 'No secret for default wallet',
            error: 'SecretNotFoundFailure',
            trace: StackTrace.current,
          );
          return Err(
            AppStartupMissingDefaultSecretFailure(wallet.masterFingerprint),
          );
        case Err(:final failure):
          log.severe(
            message: 'Seed unreadable for default wallet',
            error: failure.runtimeType.toString(),
            trace: StackTrace.current,
          );
          return Err(
            AppStartupWalletCheckFailure(
              'default secret: ${failure.runtimeType}',
            ),
          );
      }
    }
    return const Ok(true);
  }

  /// The wallet repository already logged the raw reason.
  AppStartupFailure _walletCheckFailed(WalletFailure failure) =>
      AppStartupWalletCheckFailure(
        'default wallets read failed: ${failure.runtimeType}',
      );
}
