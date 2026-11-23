import 'package:labels/labels.dart';
import 'package:labels/migration.dart';
import 'package:electrum/electrum.dart';
import 'package:electrum/migration.dart';

import 'dart:async';
import 'dart:io';

import 'package:announcements/migration.dart';
import 'package:announcements/setup.dart' show AnnouncementDismissals;
import 'package:bb_mobile/features/swap/data/order_swaps_store.dart';
import 'package:bb_mobile/storage_owner_manifest.dart';
import 'package:bull_payjoin/migration.dart';
import 'package:bull_recoverbull/migration.dart';
import 'package:swaps/migration.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:secrets/secrets.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:mempool/mempool.dart';
import 'package:mempool/migration.dart';
import 'package:primitives/primitives.dart' show Failure;
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/app_startup/public/app_startup_facade.dart';

import 'package:bull_recoverbull/bull_recoverbull.dart';

import 'package:bb_mobile/features/wallet/public/ark_foreground_setup.dart';
import 'package:bb_mobile/background_setup.dart';
import 'package:bb_mobile/background_entrypoint.dart';
import 'package:preferences/preferences.dart' show Preferences;
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bull_reporting/bull_reporting.dart';
import 'package:network/setup.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/native_libraries.dart';
import 'package:bull_payjoin/bull_payjoin.dart' show payjoinDatabaseFilename;
import 'package:bb_mobile/features/wizard/public/wizard_facade.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:btc_map/btc_map.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class Bull {
  static Future<Result<void, Failure>> init() async {
    final bullDirectory = await getApplicationDocumentsDirectory();

    await initializeLogging(
      directory: bullDirectory,
      reporter: const ReportLoggerAdapter(),
    );
    // The pre-init wizard writes consent to prefs via the bloc's
    // `SavePendingWizardChoicesUsecase` right before this runs. Pull
    // it so Sentry initializes with the user's freshest answer rather
    // than a stale mirror, and so migration errors that happen on this
    // very boot are captured if the user just opted in.
    await Report.init(
      dsn: ApiServiceConstants.sentryDsn,
      wizardConsent: await readStartupReportingConsent(),
    );

    await initFlutterRustBridgeDependencies();

    // Foreground only: background tasks never read a price, and must not open
    // the pricer's database while the app may be upgrading it.
    await Pricer.init(
      databasePath: p.join(bullDirectory.path, 'pricer.sqlite'),
    );

    await BtcMapFeature.initialize();

    // The Locator setup might depend on the initialization of the libraries above
    //  so it's important to call it after the initialization
    final support = await getApplicationSupportDirectory();
    final legacy = LegacySourceStore(
      source: LegacySource(
        File(p.join(bullDirectory.path, 'bullbitcoin_sqlite.sqlite')),
        SqliteDatabase.currentSchemaVersion,
      ),
      create: SqliteDatabase.new,
    );
    final mempoolFile = File(
      p.join(support.path, 'databases', 'mempool.sqlite'),
    );
    final electrumFile = File(
      p.join(support.path, 'databases', 'electrum.sqlite'),
    );
    final labelsFile = File(p.join(support.path, 'databases', 'labels.sqlite'));
    final announcementsFile = File(
      p.join(support.path, 'databases', 'announcements.sqlite'),
    );
    final orderSwapsFile = File(
      p.join(support.path, 'databases', 'order_swaps.sqlite'),
    );
    File destination(String owner) =>
        File(p.join(support.path, 'databases', '$owner.sqlite'));
    File standalone(String name) => File(p.join(bullDirectory.path, name));
    BoltzCutover boltzStore({required bool regtest}) {
      final owner = regtest ? 'swaps_regtest' : 'swaps';
      return BoltzCutover(
        file: destination(owner),
        standalone: standalone(
          regtest ? 'boltz_swaps_regtest.sqlite' : 'boltz_swaps.sqlite',
        ),
        regtest: regtest,
        warning: log.warning,
        executor: Secrets.databaseOpener<LegacyImportFailure>(
          file: destination(owner),
          module: owner,
          name: 'main',
          schema: BoltzCutover.schema,
          deferred: const LegacyImportDeferred(),
          unavailable: const LegacyImportUnavailable(),
        ),
      );
    }

    PayjoinCutover payjoinStore({required bool regtest}) {
      final owner = regtest ? 'payjoin_regtest' : 'payjoin';
      return PayjoinCutover(
        file: destination(owner),
        standalone: standalone(
          regtest ? 'payjoin-regtest.sqlite' : payjoinDatabaseFilename,
        ),
        regtest: regtest,
        warning: log.warning,
        executor: Secrets.databaseOpener<LegacyImportFailure>(
          file: destination(owner),
          module: owner,
          name: 'main',
          schema: PayjoinCutover.schema,
          deferred: const LegacyImportDeferred(),
          unavailable: const LegacyImportUnavailable(),
        ),
      );
    }

    final boltz = boltzStore(regtest: false);
    final regtestBoltz = boltzStore(regtest: true);
    final payjoin = payjoinStore(regtest: false);
    final regtestPayjoin = payjoinStore(regtest: true);
    final recoverBull = RecoverBullCutover(
      file: destination('recoverbull'),
      standalone: standalone('recoverbull.sqlite'),
      regtest: false,
    );
    final regtestRecoverBull = RecoverBullCutover(
      file: destination('recoverbull_regtest'),
      standalone: standalone('recoverbull-regtest.sqlite'),
      regtest: true,
    );
    final cutover = StorageCutover(
      directory: Directory(p.join(support.path, 'storage-coordination')),
      legacy: legacy,
      expectedOwners: storageOwnerManifest,
      destinationFamilies: [
        for (final owner in storageOwnerManifest)
          File(p.join(support.path, 'databases', '$owner.sqlite')),
      ],
      participants: [
        AnnouncementsStore.participant(announcementsFile, warning: log.warning),
        OrderSwapsStore.participant(orderSwapsFile),
        boltz.participant,
        regtestBoltz.participant,
        payjoin.participant,
        regtestPayjoin.participant,
        recoverBull.participant,
        regtestRecoverBull.participant,
        MempoolImport(
          file: mempoolFile,
          defaultServers: [
            ApiServiceConstants.bbMempoolUrlPath,
            ApiServiceConstants.testnetMempoolUrlPath,
            ApiServiceConstants.bbLiquidMempoolUrlPath,
            ApiServiceConstants.bbLiquidMempoolTestnetUrlPath,
          ],
        ),
        ElectrumImport(file: electrumFile),
        LabelsImport(file: labelsFile),
      ],
    );
    final admitted = await cutover.prepare();
    if (admitted case Err(:final failure)) return Err(failure);
    final admission = (admitted as Ok<RuntimeAdmission, Failure>).value;
    locator.registerSingleton<RuntimeAdmission>(
      admission,
      dispose: (value) => value.close(),
    );
    var initialized = false;
    try {
      locator.registerSingleton(payjoin);
      locator.registerSingleton(regtestPayjoin, instanceName: 'regtest');
      locator.registerSingleton(recoverBull);
      locator.registerSingleton(regtestRecoverBull, instanceName: 'regtest');
      final openedBoltz = await boltz.open(admission);
      if (openedBoltz case Err(:final failure)) return Err(failure);
      if (openedBoltz case Ok(:final value)) {
        locator.registerSingleton(
          value.database,
          dispose: (_) => value.handle.close(),
        );
      }
      final openedRegtestBoltz = await regtestBoltz.open(admission);
      if (openedRegtestBoltz case Err(:final failure)) return Err(failure);
      if (openedRegtestBoltz case Ok(:final value)) {
        locator.registerSingleton(
          value.database,
          instanceName: 'regtest',
          dispose: (_) => value.handle.close(),
        );
      }
      final announcements = await AnnouncementsStore.open(
        announcementsFile,
        admission,
      );
      if (announcements case Err(:final failure)) return Err(failure);
      if (announcements case Ok(:final value)) {
        locator.registerSingleton<AnnouncementDismissals>(
          value,
          dispose: (_) => value.close(),
        );
      }
      final orderSwaps = await OrderSwapsStore.open(orderSwapsFile, admission);
      if (orderSwaps case Err(:final failure)) return Err(failure);
      if (orderSwaps case Ok(:final value)) {
        locator.registerSingleton(
          value.database,
          dispose: (_) => value.handle.close(),
        );
      }
      final setup = await AppLocator.setup(
        locator,
        await legacy.open(admission),
        openLabels: (sync, openWallet) => Labels.open(
          file: labelsFile,
          admission: admission,
          sync: sync,
          openWallet: openWallet,
        ),
        openElectrum: (readPreferences, tor) => Electrum.open(
          file: electrumFile,
          admission: admission,
          readPreferences: readPreferences,
          tor: tor,
        ),
        openMempool: (tor, http) => Mempool.open(
          file: mempoolFile,
          admission: admission,
          tor: tor,
          torHttp: http,
        ),
        arkFundingDatabasePath: p.join(
          bullDirectory.path,
          'ark-funding.sqlite',
        ),
        initializeArkFunding: _arkProfileAdmitted && _arkInitializeNew,
      );
      if (setup case Err()) return setup;
      await initializeWalletRuntime(locator);
      // Custody inventory is already installed, independently of this profile.
      await _setupArkRegtestProfile();
      Bloc.observer = AppBlocObserver();

      // Flush wizard pending values (if any) to SQLite now that the
      // settings repository is available, then mark the wizard complete.
      final _ = await locator<ExchangeFacade>().resolveAccess();
      await completeStartupWizard(locator);
      await locator<QuickActionsCubit>().load();
      await AppLocator.setupRecoverBull(
        locator,
        databasePath: p.join(bullDirectory.path, 'recoverbull.sqlite'),
      );
      unawaited(locator<RecoverBullFacade>().checkAtColdStart());
      final settings = locator<Preferences>();
      configureLogTorContext(
        () => loadTorDiagnosticContext(settings, locator<Tor>()),
      );
      await refreshReportingConsent(settings);
      await prepareBackgroundWalletStores(locator);
      await configureBackgroundTasks();

      await Report.recordMigration();
      initialized = true;
      return const Ok(null);
    } finally {
      if (!initialized) {
        try {
          await locator.reset();
        } finally {
          await admission.close();
        }
      }
    }
  }
}

/// Explicit regtest Ark profile supplied at build time. Builds without both
/// endpoints keep the unavailable Ark routes; existing custody is still read.
/// BULL_ARK_REGTEST_INITIALIZE_NEW authorizes creating the account registry
/// and funding authority of a fresh, controlled regtest profile; it is never
/// inferred from files.
const _arkUrl = String.fromEnvironment('BULL_ARK_REGTEST_URL');
const _arkEsploraUrl = String.fromEnvironment('BULL_ARK_REGTEST_ESPLORA_URL');
const _arkInitializeNew = bool.fromEnvironment(
  'BULL_ARK_REGTEST_INITIALIZE_NEW',
);
const _arkProfileAdmitted = _arkUrl != '' && _arkEsploraUrl != '';

Future<void> _setupArkRegtestProfile() async {
  final arkUrl = Uri.tryParse(_arkUrl);
  final esploraUrl = Uri.tryParse(_arkEsploraUrl);
  if (!_arkProfileAdmitted || arkUrl == null || esploraUrl == null) return;
  await setupArkForeground(
    locator,
    arkUrl: arkUrl,
    primaryEsploraUrl: esploraUrl,
    initializeNew: _arkInitializeNew,
    dispatcher: backgroundTasksHandler,
  );
}
