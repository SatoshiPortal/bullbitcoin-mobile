import 'package:electrum/electrum.dart';
import 'package:electrum/setup.dart';
import 'package:bb_mobile/features/send/blockchain_core_locator.dart';
import 'package:bb_mobile/features/settings/data/electrum/electrum_core_locator.dart';
import 'package:bb_mobile/features/exchange/exchange_core_locator.dart';
import 'package:bull_tor/tor.dart';
import 'package:mempool/mempool.dart';
import 'package:preferences/preferences.dart' as settings;
import 'package:bb_mobile/features/settings/settings_core_locator.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/swap/swaps_core_locator.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/wallet/wallet_core_locator.dart';
import 'package:bull_tor/tor_adapter.dart' as bull_tor;
import 'package:get_it/get_it.dart';
import 'package:labels/setup.dart';

class CoreLocator {
  static void register(GetIt locator, SqliteDatabase database) {
    locator.registerLazySingleton<SqliteDatabase>(() => database);
  }

  static Future<void> registerDatasources(GetIt locator) async {
    await bull_tor.TorLocator.registerDatasources(
      locator,
      logger: bull_tor.TorLogger(
        configCallback: log.config,
        fineCallback: log.fine,
        warningCallback: log.warning,
      ),
    );
    setupElectrum(locator);
    ExchangeLocator.registerDatasources(locator);
    await SwapsLocator.registerDatasources(locator);
    await WalletLocator.registerDatasources(locator);
  }

  static void registerPorts(GetIt locator) {
    final walletSync = WalletLocator.syncAccess(locator);
    setupLabels(
      locator,
      database: locator<SqliteDatabase>(),
      sync: walletSync.foreground,
      openWallet: walletSync.openWallet,
    );
  }

  static Future<Result<void, ElectrumFailure>> registerRepositories(
    GetIt locator, {
    RegtestElectrumProfile? regtestProfile,
  }) async {
    await SettingsLocator.registerRepositories(locator);
    final settingsRepository = locator<settings.Preferences>();
    final appSettings = (await settingsRepository.fetch()).fold(
      (value) => value,
      (failure) => throw Exception('Preferences read failed'),
    );
    final prepared = await locator<ElectrumDefaultsProvisioner>()
        .prepareForegroundStorage(
          appSettings.environment.networkEnv,
          regtestProfile: regtestProfile,
        );
    if (prepared case Err()) return prepared;
    bull_tor.TorLocator.registerRepositories(
      locator,
      initialMode: appSettings.torTransportMode,
      lastSuccessfulTransport: appSettings.lastSuccessfulTorTransport,
      onSuccessfulTransport: (transport) async {
        // Best-effort cache of the working transport; the repository already
        // logged the raw reason at its boundary.
        final stored = await settingsRepository.setLastSuccessfulTorTransport(
          transport,
        );
        if (stored case Err(:final failure)) {
          log.warning(
            'Could not persist the successful Tor transport: '
            '${failure.runtimeType}',
          );
        }
      },
    );
    BlockchainLocator.registerRepositories(locator);
    ExchangeLocator.registerRepositories(locator);
    await SwapsLocator.registerRepositories(locator);
    WalletLocator.registerRepositories(locator);
    return const Ok(null);
  }

  static void registerServices(GetIt locator) {
    ExchangeLocator.registerServices(locator);
    locator.registerLazySingleton<Mempool>(
      () => Mempool.open(
        database: locator<SqliteDatabase>(),
        tor: () => locator<Tor>(),
        torHttp: locator<TorHttpClientFactory>(),
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
    bull_tor.TorLocator.registerUsecases(locator);
    BlockchainLocator.registerUsecases(locator);
    ExchangeLocator.registerUseCases(locator);
    SwapsLocator.registerUsecases(locator);
    WalletLocator.registerUsecases(locator);
  }
}
