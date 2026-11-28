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
import 'package:mempool/migration.dart';
import 'package:primitives/primitives.dart' show Failure;
import 'package:bull_quick_actions/setup.dart';
import 'package:background_tasks/wallet_jobs.dart';
import 'package:notifications/payment_store.dart' show PaymentNotificationStore;
import 'package:startup/startup.dart';

import 'package:bull_recoverbull/bull_recoverbull.dart';

import 'package:bull_ark/ark_foreground_setup.dart';
import 'package:bull_ark/ark_wallet_setup.dart'
    show arkBoardFundingBinding, SqliteArkFundingReservations;
import 'package:sync/sync.dart' show SyncReason, WalletCatalogPort;
import 'package:overview/overview.dart' show OverviewHomeController;
import 'package:overview/routes.dart' show WalletRoute;
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart' show Assets;
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:material_ui/material_ui.dart' show BoxFit, Image;
import 'package:fees/fees.dart';
import 'package:sync/write.dart'
    show ForegroundWalletSynchronization, WalletNativeRuntime;
import 'package:background_tasks/background_tasks.dart' show BackgroundSchedule;
import 'package:bb_mobile/background_entrypoint.dart';
import 'package:preferences/preferences.dart' show Environment, Preferences;
import 'package:preferences/statistics.dart' show PreferencesStatisticsNetwork;
import 'package:settings/setup.dart' show StartupNetwork;
import 'package:screen_privacy/screen_privacy.dart';
import 'package:preferences/migration.dart';
import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:bull_reporting/bull_reporting.dart';
import 'package:bull_reporting/statistics.dart';
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
    // First-run network chosen by the caller. It goes through the same
    // guarded path as the wizard's pending choice and wins over it.
    Environment? initialNetwork,
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
    const reportingDsn =
        'https://b6a8d5134da043eda72f231891c6e51a@cc.bullbitcoin.com/1';
    await Report.init(dsn: reportingDsn, wizardConsent: consent);
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
    // One authority for the isolate: the inventory grants and revokes it,
    // `Secrets` and every handle it issues follow it.
    final sessionAuthority = SessionAuthority();
    locator.registerSingleton<SessionAuthority>(sessionAuthority);
    final secrets = Secrets(
      scratchDirectory: () async => (await getTemporaryDirectory()).path,
      authority: sessionAuthority,
    );
    final signerKeys = secrets.databaseKeys(module: 'signers');
    final syncKeys = secrets.databaseKeys(module: 'sync');
    final secretsFile = destination('secrets');
    final signersFile = destination('signers');
    final syncFile = destination('sync');
    final exchangeFile = destination('exchange');
    final mempoolImport = MempoolImport(
      file: mempoolFile,
      defaultServers: [
        MempoolLegacyDefaults.bbMempoolUrlPath,
        MempoolLegacyDefaults.testnetMempoolUrlPath,
        MempoolLegacyDefaults.bbLiquidMempoolUrlPath,
        MempoolLegacyDefaults.bbLiquidMempoolTestnetUrlPath,
      ],
      retainRuntimeStore: true,
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
        mempoolImport,
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
              authority: sessionAuthority,
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
      final pendingNetwork = await startupWizard.readPendingNetwork();
      if (pendingNetwork case Err(:final failure)) return Err(failure);
      final selectedNetwork =
          initialNetwork ??
          (pendingNetwork as Ok<Environment?, WizardFailure>).value;
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
        secrets: secrets,
        openLabels: (listFreezes, freeze, openWallet) => Labels.open(
          file: labelsFile,
          admission: admission,
          listAttributedFreezes: listFreezes,
          freezeAttributedOutpoints: freeze,
          openWallet: openWallet,
          readInSession: (read) => inventory.readInSession(read),
        ),
        openElectrum: (readPreferences, tor) => Electrum.open(
          file: electrumFile,
          admission: admission,
          readPreferences: readPreferences,
          tor: tor,
        ),
        openPreferences: () =>
            Preferences.open(file: preferencesFile, admission: admission),
        openMempool: (tor, http) async => openAdmittedMempool(
          participant: mempoolImport,
          admission: admission,
          tor: tor,
          torHttp: http,
        ),
        arkFundingDatabasePath: p.join(
          bullDirectory.path,
          'ark-funding.sqlite',
        ),
        initializeArkFunding: _arkProfileAdmitted && _arkInitializeNew,
        prepareInitialNetwork: selectedNetwork == null
            ? null
            : (preferences, electrum) async {
                final result = await StartupNetwork.apply(
                  preferences: preferences,
                  electrum: electrum,
                  network: selectedNetwork.networkEnv,
                  superuserUnlocked: true,
                  developerConsent: true,
                  isProtected: inventory.isProtected,
                  hasWallets: inventory.hasWallets,
                  listSecrets: secrets.list,
                );
                if (result case Err(:final failure)) return Err(failure);
                return startupWizard.clearPendingNetwork();
              },
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
      final privacySettings = await locator<Preferences>().fetch();
      if (privacySettings case Err(:final failure)) return Err(failure);
      if (privacySettings case Ok(:final value)) {
        ScreenCaptureProtection.instance.enabledByUser =
            value.screenCaptureProtectionEnabled;
      }
      await locator<QuickActionsFeature>().preload();
      await AppLocator.setupRecoverBull(
        locator,
        databasePath: recoverBull.standalone.path,
      );
      AppLocator.setupDataBackup(
        locator,
        journalPath: p.join(
          support.path,
          'databases',
          'backup_metadata.sqlite',
        ),
      );
      if (!pinProtected) {
        locator<OverviewHomeController>().startBackupChecks();
        unawaited(locator<RecoverBullFacade>().checkAtColdStart());
      }
      final settings = locator<Preferences>();
      configureLogTorContext(
        () => loadTorDiagnosticContext(settings, locator<Tor>()),
      );
      await settings.refreshReportingConsent();
      try {
        await Statistics.instance.start(
          dsn: reportingDsn,
          network: PreferencesStatisticsNetwork(settings),
        );
      } on Exception {
        // Statistics are optional and must not block wallet startup.
      }
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

  static Future<void> startBackgroundWork() async {
    try {
      await prepareBackgroundWalletStores(
        openNotifications: () => locator<PaymentNotificationStore>().open(),
      );
    } on Exception {
      log.warning('Background wallet store preparation failed');
    }
    try {
      await locator<BackgroundSchedule>().apply();
    } on Exception {
      log.warning('Background schedule initialization failed');
    }
  }
}

/// Regtest Ark profile. Without a local `BULL_REGTEST_HOST`, it defaults to
/// the shared hosted stack (mirrored in tools/regtest/hosted.json), whose
/// fresh profiles may create their account registry and funding authority.
/// A local stack keeps Ark unavailable unless both endpoints are defined.
/// BULL_ARK_REGTEST_INITIALIZE_NEW authorizes creating the account registry
/// and funding authority of a fresh, controlled regtest profile; it is never
/// inferred from files.
const _localRegtestHost = String.fromEnvironment('BULL_REGTEST_HOST');
const _hostedRegtest = _localRegtestHost == '';
const _arkUrl = String.fromEnvironment(
  'BULL_ARK_REGTEST_URL',
  defaultValue: _hostedRegtest
      ? 'https://scuttle-regtest-ark.vibecode.casa'
      : '',
);
const _arkEsploraUrl = String.fromEnvironment(
  'BULL_ARK_REGTEST_ESPLORA_URL',
  defaultValue: _hostedRegtest
      ? 'https://scuttle-regtest-esplora.vibecode.casa'
      : '',
);
const _arkInitializeNew = bool.fromEnvironment(
  'BULL_ARK_REGTEST_INITIALIZE_NEW',
  defaultValue: _hostedRegtest,
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
    services: arkWalletAppServices(
      locator,
      walletBackground: Image.asset(
        Assets.backgrounds.bgSecureWallet.path,
        fit: BoxFit.cover,
      ),
      confirmIcon: Image.asset(
        Assets.icons.rightArrow.path,
        height: 24,
        width: 24,
      ),
      onHome: (context) => context.goNamed(WalletRoute.walletHome.name),
    ),
  );
}
