import 'package:bb_mobile/core/bip85/bip85_locator.dart';
import 'package:bb_mobile/core/bitbox/bitbox_locator.dart';
import 'package:bb_mobile/core/blockchain/blockchain_locator.dart';
import 'package:bb_mobile/core/electrum/frameworks/di/electrum_locator.dart';
import 'package:bb_mobile/core/exchange/exchange_locator.dart';
import 'package:bb_mobile/core/fees/fees_locator.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/core/ledger/ledger_locator.dart';
import 'package:bb_mobile/core/mempool/mempool_locator.dart';
import 'package:bb_mobile/core/recoverbull/recoverbull_locator.dart';
import 'package:secrets/secrets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart'
    as settings;
import 'package:bb_mobile/core/settings/settings_locator.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/storage_locator.dart';
import 'package:bb_mobile/core/swaps/swaps_locator.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/wallet_locator.dart';
import 'package:bull_tor/tor_adapter.dart' as bull_tor;
import 'package:get_it/get_it.dart';

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
    BlockchainLocator.registerDatasources(locator);
    await ElectrumLocator.registerDatasources(locator);
    ExchangeLocator.registerDatasources(locator);
    FeesLocator.registerDatasources(locator);
    await MempoolLocator.registerDatasources(locator);
    RecoverbullLocator.registerDatasources(locator);
    await StorageLocator.registerDatasources(locator);
    await SwapsLocator.registerDatasources(locator);
    await WalletLocator.registerDatasources(locator);
    await SettingsLocator.registerDatasources(locator);
    Bip85DerivationsLocator.registerDatasources(locator);
    LedgerLocator.registerDatasources(locator);
    BitBoxCoreLocator.registerDatasources(locator);
  }

  static void registerPorts(GetIt locator) {
    ElectrumLocator.registerPorts(locator);
    MempoolLocator.registerPorts(locator);
    LabelsLocator.registerPorts(locator);
  }

  static Future<void> registerRepositories(GetIt locator) async {
    await SettingsLocator.registerRepositories(locator);
    final settingsRepository = locator<settings.SettingsRepository>();
    final appSettings = await settingsRepository.fetch();
    bull_tor.TorLocator.registerRepositories(
      locator,
      initialMode: appSettings.torTransportMode,
      lastSuccessfulTransport: appSettings.lastSuccessfulTorTransport,
      onSuccessfulTransport: (transport) async {
        try {
          await settingsRepository.setLastSuccessfulTorTransport(transport);
        } catch (error, stackTrace) {
          log.warning(
            'Could not persist the successful Tor transport',
            error: error,
            trace: stackTrace,
          );
        }
      },
    );
    BlockchainLocator.registerRepositories(locator);
    ElectrumLocator.registerRepositories(locator);
    ExchangeLocator.registerRepositories(locator);
    FeesLocator.registerRepositories(locator);
    MempoolLocator.registerRepositories(locator);
    await SettingsLocator.registerRepositories(locator);
    // One instance per process, as a lazy singleton: its scratch directory and its logging context are per instance. The package's lock is per isolate; the WorkManager isolate builds its own instance and must not write the keystore. The host supplies nothing about storage.
    //
    // The temporary directory, not the documents one. Signing a PSET makes lwk
    // write its wallet cache — which carries a Liquid confidential descriptor,
    // and so the seed-derived SLIP-77 blinding key — into a fresh directory
    // under this path, removed in a finally. A process killed mid-signature
    // leaves one behind; the package sweeps `lwk_sign_*` older than ten
    // minutes, and the choice of parent bounds what the sweep misses: the OS purges its temporary directory and,
    // on iOS, excludes it from backups independently of anything this app
    // does. The documents directory is neither purged nor independently
    // excluded — it relies on a single try? in AppDelegate that fails open.
    locator.registerLazySingleton<Secrets>(
      () => Secrets(
        scratchDirectory: () async => (await getTemporaryDirectory()).path,
      ),
    );
    RecoverbullLocator.registerRepositories(locator);
    SwapsLocator.registerRepositories(locator);
    WalletLocator.registerRepositories(locator);
    Bip85DerivationsLocator.registerRepositories(locator);
    LedgerLocator.registerRepositories(locator);
    BitBoxCoreLocator.registerRepositories(locator);
  }

  static void registerServices(GetIt locator) {
    ExchangeLocator.registerServices(locator);
    MempoolLocator.registerServices(locator);
  }

  static void registerUsecases(GetIt locator) {
    bull_tor.TorLocator.registerUsecases(locator);
    LabelsLocator.registerUseCases(locator);
    ElectrumLocator.registerUsecases(locator);
    BlockchainLocator.registerUsecases(locator);
    ExchangeLocator.registerUseCases(locator);
    FeesLocator.registerUseCases(locator);
    MempoolLocator.registerUsecases(locator);
    RecoverbullLocator.registerUsecases(locator);
    SettingsLocator.registerUsecases(locator);
    SwapsLocator.registerUsecases(locator);
    WalletLocator.registerUsecases(locator);
    Bip85DerivationsLocator.registerUsecases(locator);
    LedgerLocator.registerUsecases(locator);
    BitBoxCoreLocator.registerUsecases(locator);
  }

  static void registerFacades(GetIt locator) {
    LabelsLocator.registerFacade(locator);
  }

  static void registerFrameworks(GetIt locator) {
    LabelsLocator.registerFrameworks(locator);
  }
}
