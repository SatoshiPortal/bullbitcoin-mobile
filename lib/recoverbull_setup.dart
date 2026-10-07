import 'dart:async';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/utils/result.dart';

import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_tor/tor.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

@visibleForTesting
Future<void> checkRecoverBullOnAppLaunch(
  RecoverBullAttemptMonitoringController monitoring,
) => monitoring.checkOnForeground();

@visibleForTesting
Future<void> Function() recoverBullWalletUpdatedCallback(GetIt locator) =>
    () => locator<WalletBloc>().refresh();

/// Composition root for RecoverBull. The package owns its storage and policy;
/// this adapter only supplies already-composed wallet, seed, settings and Tor
/// capabilities.
final class RecoverBullSetup {
  /// Never fails app startup: when the feature cannot be composed, the shell
  /// gets [RecoverBullFeature.unavailable] and RecoverBull stays offline until
  /// the next launch.
  static Future<void> setup(
    GetIt locator, {
    required SqliteDatabase database,
    required bool startAttemptMonitoring,
  }) async {
    final recoverBullLog = log.scoped('recoverbull');
    RecoverBullFeature composed;
    try {
      composed = await _compose(locator, database, recoverBullLog);
    } catch (error) {
      recoverBullLog.error(
        'recoverbull.setup.unavailable error_type=${error.runtimeType}',
      );
      composed = RecoverBullFeature.unavailable(log: recoverBullLog);
    }
    locator.registerSingleton<RecoverBullFeature>(composed);
    // The feature facade is the only package service registered in the shell.
    locator.registerSingleton<RecoverBullLifecycle>(composed.lifecycle);
    locator.registerSingleton<RecoverBullLifecyclePort>(composed.lifecycle);

    // Advisory only: neither the attempt check nor Drive discovery may delay
    // app startup. The background composition passes false so that neither
    // network call runs outside the foreground app.
    if (startAttemptMonitoring && composed.isAvailable) {
      unawaited(checkRecoverBullOnAppLaunch(composed.attemptMonitoring));
      unawaited(composed.discoverDriveBackups());
    }
  }

  static Future<RecoverBullFeature> _compose(
    GetIt locator,
    SqliteDatabase database,
    LogSink recoverBullLog,
  ) async {
    final documents = await getApplicationDocumentsDirectory();
    final legacySettings = await readRecoverBullLegacySettings(
      database,
      onReadFailure: () => recoverBullLog.warning(
        'recoverbull.migration.legacy_settings_read_failed',
      ),
    );
    final settingsRepository = locator<SettingsRepository>();
    final walletRepository = locator<WalletRepository>();
    final composed = await RecoverBullFeature.create(
      config: RecoverBullConfig(
        databasePath: '${documents.path}/recoverbull.sqlite',
        initialPermissionGranted: legacySettings.permissionGranted,
        initialServerUrlOverride: legacySettings.serverUrl,
      ),
      wallets: _WalletAdapter(walletRepository),
      seeds: _SeedAdapter(locator<SeedRepository>()),
      defaultWallets: _DefaultWalletsAdapter(
        locator<CreateDefaultWalletsUsecase>(),
      ),
      settings: _SettingsAdapter(settingsRepository),
      tor: locator<Tor>(),
      routePool: locator<TorRoutePool>(),
      log: recoverBullLog,
      timing: (phase, duration, outcome) =>
          _recordRecoverBullTiming(recoverBullLog, phase, duration, outcome),
      onWalletUpdated: recoverBullWalletUpdatedCallback(locator),
    );
    if (legacySettings.wasImported) {
      recoverBullLog.fine('recoverbull.migration.legacy_settings_imported');
    }
    return composed;
  }
}

@visibleForTesting
final class RecoverBullLegacySettings {
  final Uri? serverUrl;
  final bool permissionGranted;
  final bool readFailed;

  const RecoverBullLegacySettings({
    required this.serverUrl,
    required this.permissionGranted,
    this.readFailed = false,
  });

  bool get wasImported => serverUrl != null || permissionGranted;
}

@visibleForTesting
Future<RecoverBullLegacySettings> readRecoverBullLegacySettings(
  SqliteDatabase database, {
  void Function()? onReadFailure,
}) async {
  try {
    final row = await (database.select(
      database.recoverbull,
    )..where((table) => table.id.equals(1))).getSingleOrNull();
    Uri? serverUrl;
    if (row?.url case final rawUrl?
        when rawUrl != SettingsConstants.recoverbullUrl) {
      try {
        serverUrl = validateRecoverBullServerUrl(Uri.parse(rawUrl));
      } catch (_) {}
    }
    return RecoverBullLegacySettings(
      serverUrl: serverUrl,
      permissionGranted: row?.isPermissionGranted ?? false,
    );
  } catch (_) {
    onReadFailure?.call();
    return const RecoverBullLegacySettings(
      serverUrl: null,
      permissionGranted: false,
      readFailed: true,
    );
  }
}

void _recordRecoverBullTiming(
  LogSink log,
  String phase,
  int durationMilliseconds,
  String outcome,
) {
  log.fine(
    'recoverbull.timing phase=$phase '
    'duration_ms=$durationMilliseconds outcome=$outcome',
  );
}

final class _WalletAdapter implements RecoverBullWalletRepository {
  final WalletRepository _wallets;

  const _WalletAdapter(this._wallets);

  @override
  Future<Result<List<RecoverBullWallet>, RecoverBullFailure>> getWallets({
    bool onlyBitcoin = false,
    bool onlyDefaults = false,
    RecoverBullNetwork? network,
  }) async {
    final result = await _wallets.getWallets(
      environment: switch (network) {
        RecoverBullNetwork.mainnet => Environment.mainnet,
        RecoverBullNetwork.testnet => Environment.testnet,
        _ => null,
      },
      onlyBitcoin: onlyBitcoin,
      onlyDefaults: onlyDefaults,
    );
    final List<Wallet> wallets;
    switch (result) {
      case Ok(:final value):
        wallets = value;
      case Err():
        return const Err(
          RecoverBullUnexpectedFailure('Could not read the wallets'),
        );
    }
    return Ok(
      wallets
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
          .toList(growable: false),
    );
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

  @override
  Future<RecoverBullNetwork> fetchNetwork() async =>
      (await source.fetch()).environment.isTestnet
      ? RecoverBullNetwork.testnet
      : RecoverBullNetwork.mainnet;
}
