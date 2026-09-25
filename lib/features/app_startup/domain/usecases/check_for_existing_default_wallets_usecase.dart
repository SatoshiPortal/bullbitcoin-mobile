import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart' show Fingerprint;
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_startup/domain/missing_default_secret_exception.dart';

class CheckForExistingDefaultWalletsUsecase {
  final SettingsRepository _settingsRepository;
  final WalletRepository _walletRepository;
  final Secrets _secrets;

  CheckForExistingDefaultWalletsUsecase({
    required this._settingsRepository,
    required this._walletRepository,
    required this._secrets,
  });

  Future<bool> execute() async {
    final settings = await _settingsRepository.fetch();
    final environment = settings.environment;

    List<Wallet> defaultWallets;
    try {
      defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: environment,
      );
    } catch (e) {
      if (e.toString().contains('UpdateOnDifferentStatus')) {
        log.fine('UpdateOnDifferentStatus error, deleting lwkDb');
        await _walletRepository.deleteLwkDb();
        log.fine('Deleted LwkDb, retrying getWallets');
        defaultWallets = await _walletRepository.getWallets(
          onlyDefaults: true,
          environment: environment,
        );
      } else {
        rethrow;
      }
    }

    if (defaultWallets.isEmpty) {
      log.fine('No default wallets found');
      return false;
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
        final secret = switch (await _secrets.fetch(
          Fingerprint(defaultWallets.first.masterFingerprint),
        )) {
          Ok(:final value) => value,
          Err(:final failure) => throw Exception(
            'default secret unavailable: ${failure.runtimeType}',
          ),
        };
        final network = !hasBitcoin
            ? (environment.isMainnet
                  ? Network.bitcoinMainnet
                  : Network.bitcoinTestnet)
            : (environment.isMainnet
                  ? Network.liquidMainnet
                  : Network.liquidTestnet);
        await _walletRepository.createWallet(
          secret: secret,
          network: network,
          scriptType: ScriptType.bip84,
          isDefault: true,
        );
        defaultWallets = await _walletRepository.getWallets(
          onlyDefaults: true,
          environment: environment,
        );
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
        // Three outcomes, three remedies — which is the whole reason the
        // package refuses to collapse them. A locked keystore is transient
        // and the app waits for unlock; a genuine absence is the fss9 cohort
        // and the app offers a restore; anything else is a read that failed,
        // and offering a restore for that would be offering to replace a
        // seed that is still there.
        switch (await _secrets.fetch(Fingerprint(wallet.masterFingerprint))) {
          case Ok():
            log.fine('FINE: Seed Found');
          case Err(failure: SecretStoreLockedFailure()):
            log.warning(
              'Keystore locked while checking ${wallet.masterFingerprint}; '
              'waiting for unlock',
            );
            throw const KeychainLockedException();
          case Err(failure: SecretNotFoundFailure()):
            log.severe(
              message: 'No secret for default wallet — offering restore',
              error: 'SecretNotFoundFailure',
              trace: StackTrace.current,
            );
            throw MissingDefaultSecretException(wallet.masterFingerprint);
          case Err(:final failure):
            log.severe(
              message: 'Seed unreadable for default wallet',
              error: failure.runtimeType.toString(),
              trace: StackTrace.current,
            );
            throw Exception('default secret: ${failure.runtimeType}');
        }
      }),
    );
    return true;
  }
}
