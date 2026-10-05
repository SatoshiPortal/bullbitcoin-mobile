import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:meta/meta.dart';

class CheckForExistingDefaultWalletsUsecase {
  final SettingsRepository _settingsRepository;
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;

  CheckForExistingDefaultWalletsUsecase({
    required this._settingsRepository,
    required this._walletRepository,
    required this._seedRepository,
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
      // LWK disagrees with its own stored status: drop its database and retry
      // once. Keyed on the failure type now, not on matching the words
      // "UpdateOnDifferentStatus" in an exception string.
      case Err(failure: WalletLwkStatusConflictFailure()):
        log.fine('LWK status conflict, deleting lwkDb');
        await _walletRepository.deleteLwkDb();
        log.fine('Deleted LwkDb, retrying getWallets');
        switch (await _walletRepository.getWallets(
          onlyDefaults: true,
          environment: environment,
        )) {
          case Ok(:final value):
            defaultWallets = value;
          case Err(:final failure):
            return Err(_walletCheckFailed(failure));
        }
      case Err(:final failure):
        return Err(_walletCheckFailed(failure));
    }

    if (defaultWallets.isEmpty) {
      log.fine('No default wallets found');
      return const Ok(false);
    }

    final hasBitcoin = defaultWallets.any((w) => w.network.isBitcoin);
    final hasLiquid = defaultWallets.any((w) => w.network.isLiquid);
    if (!hasBitcoin || !hasLiquid) {
      final missing = !hasBitcoin ? 'bitcoin' : 'liquid';
      log.severe(
        message:
            'CheckForExistingDefaultWalletsUsecase: partial default set at cold start',
        error: StateError('missing $missing default wallet'),
        trace: StackTrace.current,
      );
      try {
        final seed = await _seedRepository.get(
          defaultWallets.first.masterFingerprint,
        );
        final network = !hasBitcoin
            ? (environment.isMainnet
                  ? Network.bitcoinMainnet
                  : Network.bitcoinTestnet)
            : (environment.isMainnet
                  ? Network.liquidMainnet
                  : Network.liquidTestnet);
        await _walletRepository.createWallet(
          seed: seed,
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
    await Future.wait(
      defaultWallets.map((wallet) async {
        try {
          await _seedRepository.get(wallet.masterFingerprint);
          log.fine('FINE: Seed Found');
        } catch (e) {
          log.severe(
            message: 'Seed not found for default wallet ',
            error: e,
            trace: StackTrace.current,
          );
          rethrow;
        }
      }),
    );
    return const Ok(true);
  }

  /// The wallet repository already logged the raw reason.
  AppStartupFailure _walletCheckFailed(WalletFailure failure) =>
      AppStartupWalletCheckFailure(
        'default wallets read failed: ${failure.runtimeType}',
      );
}
