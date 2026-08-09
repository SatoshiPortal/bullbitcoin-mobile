import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:bb_mobile/bloc_observer.dart';
import 'package:bb_mobile/core/background_tasks/handler.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/screens/app_init_error_screen.dart';
import 'package:bb_mobile/core/screens/local_data_recovery_screen.dart';
import 'package:bb_mobile/core/screens/startup_keychain_locked_screen.dart';
import 'package:bb_mobile/core/storage/backup_exclusion.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/database_encryption_key_store.dart';
import 'package:bb_mobile/core/storage/database_key_unavailable_exception.dart';
import 'package:bb_mobile/core/storage/local_database_reset.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/report.dart';

import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_startup/ui/app_startup_widget.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_listener.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:bb_mobile/features/wizard/data/repository/wizard_repository_impl.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/apply_pending_wizard_choices_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/is_wizard_complete_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/read_pending_wizard_choices_usecase.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_app.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:bitbox_transport/bitbox_transport.dart';
import 'package:bull_sdk/bull_sdk.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:bull_tor/tor_adapter.dart' as tor;
import 'package:workmanager/workmanager.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

/// Builds a [WizardRepository] without going through the locator. Used
/// only in `main()` for the pre-init / pre-locator window: the wizard
/// always runs before `Bull.init` (fresh installs and upgrades alike)
/// so Sentry captures migration errors with the user's freshest answer
/// and so consent is collected before any migration / network work.
/// Same shape as the locator-supplied repository — the bloc behaves
/// identically in both timing paths.
WizardRepository _buildPreInitWizardRepository() =>
    WizardRepositoryImpl(WizardLocalDatasourceImpl());

@visibleForTesting
void resumePayjoinsOnAppResume(
  AppLifecycleState state,
  PayjoinLifecycle lifecycle,
) {
  if (state == AppLifecycleState.resumed) {
    unawaited(lifecycle.resume());
  }
}

class Bull {
  /// Guards the process-wide, one-shot half of [init].
  ///
  /// [init] is re-entrant now: a boot that hits a locked keychain, or
  /// one the user resolves by resetting local data, runs it again.
  /// Everything below this flag installs a process-level singleton —
  /// `SentryFlutter.init` re-registers the native crash handler,
  /// `BullSdk.init` and `BitBoxApi.initialize` bind flutter_rust_bridge
  /// — and running any of them twice is at best wasteful and at worst
  /// corrupting. The locator setup below the flag *is* safe to redo,
  /// because a retry only ever happens on a path that failed before
  /// reaching it.
  static bool _oneTimeInitDone = false;

  /// Absolute paths of the local databases, sidecar suffixes excluded.
  /// Cached at [initLocator] so the lifecycle sweep and the recovery
  /// screen don't each have to re-derive them.
  static List<String> _databasePaths = const [];

  /// Empty until [initLocator] has run far enough to derive them.
  static List<String> get databasePaths => _databasePaths;

  static Future<void> init({String? payjoinDatabasePath}) async {
    if (!_oneTimeInitDone) {
      await initLogs();
      // The pre-init wizard writes consent to prefs via the bloc's
      // `SavePendingWizardChoicesUsecase` right before this runs. Pull
      // it so Sentry initializes with the user's freshest answer rather
      // than a stale mirror, and so migration errors that happen on this
      // very boot are captured if the user just opted in.
      final preInitRepo = _buildPreInitWizardRepository();
      final pending = await ReadPendingWizardChoicesUsecase(
        repository: preInitRepo,
      ).execute();
      await Report.init(wizardConsent: pending?.reportingConsent);
      await initFlutterRustBridgeDependencies();
      _oneTimeInitDone = true;
    }
    // The Locator setup might depend on the initialization of the libraries above
    //  so it's important to call it after the initialization
    await initLocator(payjoinDatabasePath: payjoinDatabasePath);
    // Flush wizard pending values (if any) to SQLite now that the
    // settings repository is available, then mark the wizard complete.
    await locator<ApplyPendingWizardChoicesUsecase>().execute();
    final settings = locator<SettingsRepository>();
    Report.consent = (await settings.fetch()).isErrorReportingEnabled;
    if (Platform.isAndroid || Platform.isIOS) {
      await initWorkmanager();
    }
    // Emits the install/upgrade transition event (no-op on a normal
    // launch) and advances the persisted version marker. The shout is
    // awaited so a crash between scheduling and capture cannot lose
    // the milestone — the persisted marker only advances once Sentry
    // has the event.
    final type = Report.migrationType;
    if (type != null) {
      await log.shout(message: type.name, category: ReportCategory.migration);
      await Report.commitVersion();
    }
  }

  static Future<void> initFlutterRustBridgeDependencies() async {
    final initTasks = [
      BullSdk.init(),
      if (Platform.isAndroid) BitBoxApi.initialize(),
    ];

    await Future.wait(initTasks);
  }

  /// [background] — when true, the logger writes to
  /// `bull_background_logs.tsv` instead of `bull_logs.tsv`. Required
  /// for the workmanager BG isolate so its writes don't interleave
  /// with the main isolate's (both engines can be alive simultaneously
  /// inside the same iOS process when iOS spawns the app to fire a
  /// periodic task).
  static Future<void> initLogs({bool background = false}) async {
    final logDirectory = await getApplicationDocumentsDirectory();
    log = Logger.replace(directory: logDirectory, background: background);
    await log.ensureLogsExist();
    if (!background) {
      // Cold-start prune for the FG file. `Logger.prune()` is
      // intentionally per-isolate (see the comment above its
      // definition — cross-isolate truncation races with the other
      // isolate's open IOSink and can destroy recently-buffered
      // lines). FG file pruning therefore only happens here; the BG
      // file no longer grows because background tasks are disabled. Long
      // FG-only sessions (rare cold restarts) can let the FG file grow past
      // the cap until the next cold launch —
      // acceptable: worst case is a few hundred KB until the user
      // restarts.
      //
      // Fire-and-forget: prune serializes against writes via
      // `_enqueue` and is a no-op if the file is small.
      unawaited(log.prune());
    }
  }

  static Future<void> initLocator({String? payjoinDatabasePath}) async {
    final databaseDirectory = await getApplicationDocumentsDirectory();
    _databasePaths = [
      p.join(databaseDirectory.path, '${SqliteDatabase.name}.sqlite'),
      payjoinDatabasePath ?? p.join(databaseDirectory.path, 'payjoin.sqlite'),
    ];
    final hasDatabaseRequiringExistingKey =
        await DatabaseEncryptionKeyStore.hasDatabaseRequiringExistingKey(
          _databasePaths.map(File.new),
        );
    final databaseKey = await DatabaseEncryptionKeyStore.loadOrCreate(
      hasDatabaseRequiringExistingKey: hasDatabaseRequiringExistingKey,
    );
    // Payjoin existed as plaintext on source-built `develop` installs.
    // Migrate it synchronously so startup does not report success while
    // an unawaited recovery task is still changing its storage format.
    await SqliteDatabase.encryptExistingDatabase(
      File(_databasePaths[1]),
      databaseKey,
    );
    await AppLocator.setup(
      locator,
      await SqliteDatabase.openEncrypted(databaseKey),
      databaseKey: databaseKey,
      payjoinDatabasePath: payjoinDatabasePath,
    );
    // First pass, so a fresh install is protected from the very first
    // backup window. `payjoin.sqlite` is opened lazily by the payjoin
    // runtime and the `-wal`/`-shm` sidecars only appear on first write,
    // so this can't catch everything — `_excludeDatabasesFromBackup` runs
    // again when the app goes to the background, which is the state a
    // device is in when iCloud actually backs it up.
    await excludeDatabasesFromBackup();
    Bloc.observer = AppBlocObserver();
  }

  /// Re-marks the local databases as "do not back up". Cheap, idempotent
  /// and a no-op off iOS.
  static Future<void> excludeDatabasesFromBackup() =>
      BackupExclusion.excludeDatabases(_databasePaths);

  static Future<void> initWorkmanager() async {
    await Workmanager().initialize(backgroundTasksHandler);
    // Background execution is intentionally disabled. Cancel schedules left
    // by previous releases, but keep initialization so upgrades reliably
    // remove those persisted native tasks.
    await Workmanager().cancelAll();
  }
}

/// Runs `Bull.init` and puts on screen whichever of the four outcomes it
/// produced.
///
/// Split out of [main] because two of those outcomes are recoverable and
/// their screens call straight back into it: unlocking the device, or
/// resetting local data, re-runs startup in place rather than asking the
/// user to kill and relaunch the app.
Future<void> startApp() async {
  try {
    await Bull.init();
  } on KeychainLockedException catch (error) {
    // Not an error: the device simply has not been unlocked since boot,
    // so a `first_unlock_this_device` keychain item is unreadable. The
    // data is intact and nothing must be created, deleted or migrated —
    // the user just has to unlock. Logged at warning, never severe, so
    // it doesn't drown the real failures in a shared log.
    log.warning('App init deferred: $error');
    await log.flush();
    runApp(StartupKeychainLockedScreen(onRetry: startApp));
    return;
  } on DatabaseKeyUnavailableException catch (error, stackTrace) {
    // Fail closed: a database exists that nothing can open. The generic
    // error screen would leave the user with no action here, so this one
    // offers the only real one — a confirmed local-data reset.
    log.severe(
      message: 'App init failed closed: local database key unavailable',
      error: error,
      trace: stackTrace,
    );
    await log.flush();
    runApp(
      LocalDataRecoveryScreen(
        onReset: () => LocalDatabaseReset.run(Bull.databasePaths),
        onRestart: startApp,
        error: error,
      ),
    );
    return;
  } catch (error, stackTrace) {
    log.severe(message: 'App Init Error', error: error, trace: stackTrace);
    // Make sure the just-logged severe line is on disk before we
    // render AppInitErrorScreen — the user typically shares logs
    // from that screen to support, and the buffered severe write
    // would otherwise still be pending in the IOSink.
    await log.flush();
    runApp(AppInitErrorScreen(error: error));
    return;
  }
  await log.flush();
  runApp(const BullBitcoinWalletApp());
}

Future main() async {
  await runZonedGuarded(
    () async {
      try {
        WidgetsFlutterBinding.ensureInitialized();
        // Wizard runs BEFORE `Bull.init` for everyone — fresh installs
        // and upgrades alike — so consent is collected before
        // migrations / Sentry init / Drift schema work fires off, and
        // bumping `kCurrentWizardVersion` re-prompts every user
        // uniformly without any per-install branching.
        final preInitRepo = _buildPreInitWizardRepository();
        final isComplete = await IsWizardCompleteUsecase(
          repository: preInitRepo,
        ).execute();
        if (!isComplete) {
          final completer = Completer<void>();
          runApp(WizardApp(onDone: (_) => completer.complete()));
          await completer.future;
        }
      } catch (error, stackTrace) {
        log.severe(message: 'App Init Error', error: error, trace: stackTrace);
        await log.flush();
        runApp(AppInitErrorScreen(error: error));
        return;
      }
      await startApp();
    },
    (error, stackTrace) {
      // Use try-catch to prevent cascading crashes if logging itself fails
      try {
        log.severe(
          message: 'Global Unhandled Error',
          error: error,
          trace: stackTrace,
        );
      } catch (_) {
        debugPrint(
          'Global Unhandled Error (logger failed): $error\n$stackTrace',
        );
      } finally {
        // Best-effort: push the just-queued severe write to disk before
        // a potential subsequent crash takes the isolate down. The
        // handler signature is synchronous so we can't await here;
        // `_queueWrite` is itself `unawaited` for SEVERE flushes which
        // means this scheduled flush is still racy at process death.
        // Sentry preserves the event independently via `Report.error`.
        unawaited(log.flush());
      }
    },
  );
}

class BullBitcoinWalletApp extends StatefulWidget {
  const BullBitcoinWalletApp({super.key});

  @override
  State<BullBitcoinWalletApp> createState() => _BullBitcoinWalletAppState();
}

class _BullBitcoinWalletAppState extends State<BullBitcoinWalletApp> {
  late final AppLifecycleListener _listener;
  late final tor.TorLifecycleController _torLifecycleController;
  // final router = AppRouter.router;

  @override
  void initState() {
    super.initState();

    _torLifecycleController = locator<tor.TorLifecycleController>()..start();
    // Initialize the AppLifecycleListener class and pass callbacks
    _listener = AppLifecycleListener(onStateChange: _onStateChanged);
  }

  @override
  void dispose() {
    // Do not forget to dispose the listener
    _listener.dispose();
    if (locator.isRegistered<PayjoinLifecycle>()) {
      unawaited(locator<PayjoinLifecycle>().dispose());
    }
    _torLifecycleController.dispose();

    super.dispose();
  }

  // Wallet/swap sync on resume is handled by SyncCoordinator's own
  // AppLifecycleListener — see lib/core/sync/sync_coordinator.dart.
  void _onStateChanged(AppLifecycleState state) {
    log.info(state.name);
    if (locator.isRegistered<PayjoinLifecycle>()) {
      resumePayjoinsOnAppResume(state, locator<PayjoinLifecycle>());
    }
    // iOS lifecycle is `active → inactive → hidden → paused`. The user can
    // force-quit from the app switcher during `inactive` and skip both the
    // `hidden` and `paused` flushes, so flush there too.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      log.flush();
    }
    if (state == AppLifecycleState.paused) {
      // Backgrounding is the last moment we control before iOS may back
      // the container up (backups run while the device is locked and
      // charging, with the app not in the foreground). By now the
      // lazily-opened payjoin database and the `-wal`/`-shm` sidecars
      // exist, which the pass during `initLocator` could not assume.
      unawaited(Bull.excludeDatabasesFromBackup());
    }
  }

  @override
  Widget build(BuildContext context) {
    Device.init(context);

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => locator<SettingsCubit>()..init()),
        BlocProvider(
          create: (_) =>
              locator<AppStartupBloc>()..add(const AppStartupStarted()),
        ),
        BlocProvider(
          create: (_) =>
              locator<BitcoinPriceBloc>()..add(const BitcoinPriceStarted()),
        ),
        // Make the wallet bloc available to the whole app so environment changes
        // from anywhere (wallet or exchange tab) can trigger a re-fetch of the wallets.
        BlocProvider(create: (_) => locator<WalletBloc>()),
        // Make the exchange cubit available to the whole app so redirects
        // can use it to check if the user is authenticated
        BlocProvider(create: (_) => locator<ExchangeCubit>()),
      ],
      child: ExchangeListener(
        child: MultiBlocListener(
          listeners: [
            BlocListener<AppStartupBloc, AppStartupState>(
              listenWhen: (previous, current) =>
                  previous != current &&
                  current is AppStartupSuccess &&
                  current.hasDefaultWallets,
              listener: (context, settings) {
                // If wallets exist and the app has started successfully,
                // we can start the wallet bloc to fetch the wallets.
                context.read<WalletBloc>().add(const WalletStarted());
                // Also fetch user summary to check if user is logged in
                // and connect WebSocket if so (handled by ExchangeListener)
                context.read<ExchangeCubit>().fetchUserSummary();
                // Reconnect WebSocket here too — when AppStartupBloc retries
                // after a pre-warm KeychainLockedException, the SettingsCubit
                // env-change listener below has ALREADY fired during pre-warm
                // (with the keychain locked) and won't fire again, so without
                // this call the WebSocket stays disconnected post-unlock until
                // the user toggles environment or cold-launches.
                context.read<ExchangeCubit>().reconnectWebSocket();
              },
            ),
            BlocListener<SettingsCubit, SettingsState>(
              listenWhen: (previous, current) =>
                  previous.environment != current.environment,
              listener: (context, settings) async {
                // Re-fetch user summary (re-init exchange bloc) and wallets
                //  when environment changes
                context.read<WalletBloc>().add(const WalletStarted());
                await context.read<ExchangeCubit>().fetchUserSummary();
                // Reconnect WebSocket for the new environment
                await context.read<ExchangeCubit>().reconnectWebSocket();
              },
            ),
          ],
          child:
              BlocSelector<
                SettingsCubit,
                SettingsState,
                (Language?, AppThemeMode?)
              >(
                selector: (settings) =>
                    (settings.language, settings.storedSettings?.themeMode),
                builder: (context, data) {
                  final (language, themeMode) = data;
                  final systemBrightness = MediaQuery.platformBrightnessOf(
                    context,
                  );
                  final effectiveThemeMode = themeMode ?? AppThemeMode.system;

                  late final AppThemeType appThemeType;
                  switch (effectiveThemeMode) {
                    case AppThemeMode.light:
                      appThemeType = AppThemeType.light;
                    case AppThemeMode.dark:
                      appThemeType = AppThemeType.dark;
                    case AppThemeMode.system:
                      appThemeType = systemBrightness == .dark
                          ? AppThemeType.dark
                          : AppThemeType.light;
                  }

                  return MaterialApp.router(
                    title: 'BullBitcoin Wallet',
                    debugShowCheckedModeBanner: kDebugMode,
                    routerConfig: AppRouter.router,
                    theme: AppTheme.themeData(appThemeType),
                    locale: language?.locale,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) {
                      final app = AppStartupWidget(app: child!);
                      // Mark beta-channel builds (`make android beta`) with a
                      // corner banner. Release mode drops the Flutter debug
                      // banner, so this is how testers tell beta from production.
                      if (appFlavor != 'beta') return app;
                      return Banner(
                        message: 'BETA',
                        location: BannerLocation.topEnd,
                        color: Theme.of(context).colorScheme.error,
                        child: app,
                      );
                    },
                  );
                },
              ),
        ),
      ),
    );
  }
}
