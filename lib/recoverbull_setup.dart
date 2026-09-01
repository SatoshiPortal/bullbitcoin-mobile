import 'dart:async';

import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_tor/tor.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

/// Composition root for RecoverBull. The package owns its storage and policy;
/// this adapter only supplies already-composed wallet, seed, settings and Tor
/// capabilities.
final class RecoverBullSetup {
  static Future<void> setup(
    GetIt locator, {
    required SqliteDatabase database,
    required bool startAttemptMonitoring,
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    final initialPermissionGranted = await _readLegacyPermission(database);
    final settingsRepository = locator<SettingsRepository>();
    final walletRepository = locator<WalletRepository>();
    final composed = await RecoverBullFeature.create(
      config: RecoverBullConfig(
        databasePath: '${documents.path}/recoverbull.sqlite',
        initialPermissionGranted: initialPermissionGranted,
      ),
      wallets: _WalletAdapter(walletRepository),
      seeds: _SeedAdapter(locator<SeedRepository>()),
      defaultWallets: _DefaultWalletsAdapter(
        locator<CreateDefaultWalletsUsecase>(),
      ),
      settings: _SettingsAdapter(settingsRepository),
      tor: locator<Tor>(),
      logger: const _RecoverBullLogger(),
      timing: _recordRecoverBullTiming,
    );
    locator.registerSingleton<RecoverBullFeature>(composed);
    // The feature facade is the only package service registered in the shell.
    locator.registerSingleton<RecoverBullLifecycle>(composed.lifecycle);
    locator.registerSingleton<RecoverBullLifecyclePort>(composed.lifecycle);

    // Advisory only: an attempt monitoring outage must never delay app startup. The
    // background composition passes false and therefore does not open this DB.
    if (startAttemptMonitoring) {
      unawaited(
        composed.attemptMonitoring.checkOnColdLaunch().catchError(
          (_) => const <RecoverBullAttemptAlert>[],
        ),
      );
    }
  }
}

Future<bool> _readLegacyPermission(SqliteDatabase database) async {
  try {
    final row = await (database.select(
      database.recoverbull,
    )..where((table) => table.id.equals(1))).getSingleOrNull();
    return row?.isPermissionGranted ?? false;
  } catch (_) {
    return false;
  }
}

void _recordRecoverBullTiming(
  String phase,
  int durationMilliseconds,
  String outcome,
) {
  log.info(
    'RecoverBull timing phase=$phase '
    'duration_ms=$durationMilliseconds outcome=$outcome',
  );
}

final class _WalletAdapter implements RecoverBullWalletRepository {
  final WalletRepository _wallets;

  const _WalletAdapter(this._wallets);

  @override
  Future<List<RecoverBullWallet>> getWallets({
    bool onlyBitcoin = false,
    bool onlyDefaults = false,
    RecoverBullNetwork? network,
  }) async {
    final wallets = await _wallets.getWallets(
      environment: switch (network) {
        RecoverBullNetwork.mainnet => Environment.mainnet,
        RecoverBullNetwork.testnet => Environment.testnet,
        _ => null,
      },
      onlyBitcoin: onlyBitcoin,
      onlyDefaults: onlyDefaults,
    );
    return wallets
        .map(
          (wallet) => RecoverBullWallet(
            id: wallet.id,
            masterFingerprint: wallet.masterFingerprint,
            network: wallet.network.isTestnet
                ? RecoverBullNetwork.testnet
                : RecoverBullNetwork.mainnet,
            isPhysicalBackupTested: wallet.isPhysicalBackupTested,
            latestPhysicalBackup: wallet.latestPhysicalBackup,
          ),
        )
        .toList(growable: false);
  }
}

final class _SeedAdapter implements RecoverBullSeedPort {
  final SeedRepository source;
  const _SeedAdapter(this.source);
  @override
  Future<RecoverBullSeedMaterial> getSeed(String fingerprint) async {
    final seed = await source.get(fingerprint);
    return RecoverBullSeedMaterial(
      bytes: seed.bytes.toList(),
      mnemonicWords: seed is MnemonicSeed
          ? seed.mnemonicWords.toList()
          : <String>[],
    );
  }
}

final class _DefaultWalletsAdapter implements RecoverBullDefaultWalletsPort {
  final CreateDefaultWalletsUsecase source;
  const _DefaultWalletsAdapter(this.source);
  @override
  Future<List<RecoverBullWallet>> execute({
    required List<String> mnemonicWords,
  }) async {
    final wallets = await source.execute(mnemonicWords: mnemonicWords);
    return wallets
        .map(
          (wallet) => RecoverBullWallet(
            id: wallet.id,
            masterFingerprint: wallet.masterFingerprint,
            network: wallet.network.isTestnet
                ? RecoverBullNetwork.testnet
                : RecoverBullNetwork.mainnet,
            isPhysicalBackupTested: wallet.isPhysicalBackupTested,
            latestPhysicalBackup: wallet.latestPhysicalBackup,
          ),
        )
        .toList(growable: false);
  }
}

final class _SettingsAdapter implements RecoverBullSettingsPort {
  final SettingsRepository source;
  const _SettingsAdapter(this.source);
  @override
  Future<RecoverBullTorSettings> fetch() async {
    final settings = await source.fetch();
    return RecoverBullTorSettings(
      useTorProxy: settings.useTorProxy,
      torProxyPort: settings.torProxyPort,
    );
  }
}

final class _RecoverBullLogger implements RecoverBullLogger {
  const _RecoverBullLogger();

  @override
  void fine(String message, {Object? error, StackTrace? trace}) {
    log.fine(message, error: error, trace: trace);
  }

  @override
  void info(String message, {Object? error, StackTrace? trace}) {
    log.info(message, error: error, trace: trace);
  }

  @override
  void warning(String message, {Object? error, StackTrace? trace}) {
    log.warning(message, error: error, trace: trace);
  }

  @override
  void error(String code, {Object? error, StackTrace? trace}) {
    log.severe(
      message: code,
      error: error ?? code,
      trace: trace ?? StackTrace.current,
    );
  }
}
