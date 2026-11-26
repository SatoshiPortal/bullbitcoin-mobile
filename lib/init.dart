import 'package:startup/setup.dart' show AppBlocObserver;
import 'package:labels/labels.dart';
import 'package:labels/migration.dart';
import 'package:electrum/electrum.dart';
import 'package:electrum/migration.dart';

import 'dart:async';
import 'dart:io';

import 'package:announcements/migration.dart';
import 'package:announcements/setup.dart' show AnnouncementDismissals;
import 'package:bb_mobile/storage_owner_manifest.dart';
import 'package:bull_payjoin/migration.dart';
import 'package:bull_recoverbull/migration.dart';
import 'package:swaps/migration.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:secrets/migration.dart' show SecretsImport;
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:signers/storage.dart';
import 'package:sync/storage.dart';
import 'package:bb_mobile/wallet_inventory_setup.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:mempool/mempool.dart';
import 'package:mempool/migration.dart';
import 'package:primitives/primitives.dart' show Failure;
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:background_tasks/wallet_jobs.dart';
import 'package:notifications/payment_store.dart' show PaymentNotificationStore;
import 'package:startup/startup.dart';

import 'package:bull_recoverbull/bull_recoverbull.dart';

import 'package:bull_ark/ark_foreground_setup.dart';
import 'package:bull_ark/ark_wallet_setup.dart'
    show arkBoardFundingBinding, SqliteArkFundingReservations;
import 'package:sync/sync.dart' show SyncReason, WalletCatalogPort;
import 'package:bb_mobile/features/wallet/wallet_ark_services.dart';
import 'package:fees/fees.dart';
import 'package:sync/write.dart'
    show ForegroundWalletSynchronization, WalletNativeRuntime;
import 'package:background_tasks/background_tasks.dart' show BackgroundSchedule;
import 'package:bb_mobile/background_entrypoint.dart';
import 'package:preferences/preferences.dart' show Preferences;
import 'package:preferences/migration.dart';
import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:bull_reporting/bull_reporting.dart';
import 'package:network/setup.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/native_libraries.dart';
import 'package:bull_payjoin/bull_payjoin.dart' show payjoinDatabaseFilename;
import 'package:exchange/exchange.dart' show Exchange;
import 'package:exchange/migration.dart' show ExchangeCredentialImport;
import 'package:exchange/setup.dart' show ExchangeCredentialStorage;
import 'package:wizard/wizard.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:btc_map/btc_map.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class Bull {
  static Future<Result<void, Failure>> init({
    Future<void> Function(LegacyImportFailure)? retryStorage,
    Future<void> Function(InventoryRecoveryRequired)? blockedInventory,
    WizardFeature? wizard,
  }) async {
    final startupWizard = wizard ?? WizardFeature.mount();
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
    final wizardConsent = await startupWizard.readReportingConsent();
    final bool? consent;
    switch (wizardConsent) {
      case Ok(:final value):
        consent = value;
      case Err(:final failure):
        return Err(failure);
    }
    await Report.init(
      dsn: 'https://b6a8d5134da043eda72f231891c6e51a@cc.bullbitcoin.com/1',
      wizardConsent: consent,
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
    final preferencesFile = File(
      p.join(support.path, 'databases', 'preferences.sqlite'),
    );
    final secrets = Secrets(
      scratchDirectory: () async => (await getTemporaryDirectory()).path,
    );
    final signerKeys = secrets.databaseKeys(module: 'signers');
    final syncKeys = secrets.databaseKeys(module: 'sync');
    final secretsFile = destination('secrets');
    final signersFile = destination('signers');
    final syncFile = destination('sync');
    final exchangeFile = destination('exchange');
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
        SecretsImport(file: secretsFile),
        signersWalletMetadataImport(file: signersFile, keys: signerKeys),
        syncWalletMetadataImport(file: syncFile, keys: syncKeys),
        PreferencesImport(
          file: preferencesFile,
          defaultRecoverBullServerUrl: recoverBullDefaultServerUrl,
          readStandalonePermission: () async =>
              (await readLegacyRecoverBullPermission(recoverBull.standalone))
                  .mapErr((_) => const LegacyImportUnavailable()),
        ),
        MempoolImport(
          file: mempoolFile,
          defaultServers: [
            MempoolLegacyDefaults.bbMempoolUrlPath,
            MempoolLegacyDefaults.testnetMempoolUrlPath,
            MempoolLegacyDefaults.bbLiquidMempoolUrlPath,
            MempoolLegacyDefaults.bbLiquidMempoolTestnetUrlPath,
          ],
        ),
        ElectrumImport(file: electrumFile),
        LabelsImport(file: labelsFile),
        ExchangeCredentialImport(file: exchangeFile, secrets: secrets),
      ],
    );
    final admittedInventory =
        await admitInventory<RuntimeAdmission, SecretsInventory>(
          prepare: () => cutover.prepare(),
          openInventory: (admission) async {
            locator.registerSingleton<RuntimeAdmission>(
              admission,
              dispose: (value) => value.close(),
            );
            return openWalletInventory(
              locator,
              admission: admission,
              legacy: legacy.source,
              inventoryFile: secretsFile,
              signersFile: signersFile,
              syncFile: syncFile,
              signerKeys: signerKeys,
              syncKeys: syncKeys,
              recoverBull: recoverBull,
              regtestRecoverBull: regtestRecoverBull,
            );
          },
          release: (admission) async {
            try {
              await locator.reset();
            } finally {
              await admission.close();
            }
          },
          retryStorage: retryStorage,
          blockedInventory: blockedInventory,
        );
    if (admittedInventory case Err(:final failure)) return Err(failure);
    final (:admission, :inventory) =
        (admittedInventory
                as Ok<
                  AdmittedInventory<RuntimeAdmission, SecretsInventory>,
                  Failure
                >)
            .value;
    var initialized = false;
    try {
      final protection = await inventory.isProtected();
      if (protection case Err(:final failure)) return Err(failure);
      final pinProtected = (protection as Ok<bool, SecretFailure>).value;
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
          value.orders,
          dispose: (_) => value.handle.close(),
        );
      }
      // Existing-only: a store that is missing or unreadable after admission
      // blocks startup rather than reading as a signed-out user.
      final exchangeStorage = await ExchangeCredentialStorage.open(
        file: exchangeFile,
        admission: admission,
      );
      if (exchangeStorage case Err(:final failure)) return Err(failure);
      if (exchangeStorage case Ok(:final value)) {
        locator.registerSingleton<ExchangeCredentialStorage>(
          value,
          dispose: (_) => value.close(),
        );
      }
      final setup = await AppLocator.setup(
        locator,
        await legacy.open(admission),
        secrets: secrets,
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
        openPreferences: () =>
            Preferences.open(file: preferencesFile, admission: admission),
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
      if (!pinProtected) await locator<ForegroundWalletStartup>().start();
      // Custody inventory is already installed, independently of this profile.
      await _setupArkRegtestProfile();
      Bloc.observer = AppBlocObserver();

      // Flush wizard pending values (if any) to SQLite now that the
      // settings repository is available, then mark the wizard complete.
      final _ = await locator<Exchange>().resolveAccess();
      final applied = await startupWizard.applyPendingChoices(
        preferences: locator<Preferences>(),
        exchange: locator<Exchange>(),
      );
      if (applied case Err(:final failure)) return Err(failure);
      await locator<QuickActionsCubit>().load();
      await AppLocator.setupRecoverBull(
        locator,
        databasePath: recoverBull.standalone.path,
      );
      if (!pinProtected) {
        unawaited(locator<RecoverBullFacade>().checkAtColdStart());
      }
      final settings = locator<Preferences>();
      configureLogTorContext(
        () => loadTorDiagnosticContext(settings, locator<Tor>()),
      );
      await settings.refreshReportingConsent();
      await prepareBackgroundWalletStores(
        openNotifications: () => locator<PaymentNotificationStore>().open(),
      );
      await locator<BackgroundSchedule>().apply();

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
  await ArkForegroundHost.setup(
    locator,
    inventory: locator<SecretsInventory>(),
    boardFunding: () => arkBoardFundingBinding(
      authority: locator<SqliteArkFundingReservations>(),
      runtime: locator<WalletNativeRuntime>(),
      inventory: locator<SecretsInventory>(),
      synchronize: (key) =>
          locator<ForegroundWalletSynchronization>().executeKey(
            key,
            locator<WalletCatalogPort>(),
            reason: SyncReason.manual,
          ),
      secrets: locator<Secrets>(),
      fees: locator<Fees>(),
      custody: locator<ParentCustodyAdmissionPort>(),
    ),
    arkUrl: arkUrl,
    primaryEsploraUrl: esploraUrl,
    initializeNew: _arkInitializeNew,
    dispatcher: backgroundTasksHandler,
    services: walletArkAppServices(locator),
  );
}
