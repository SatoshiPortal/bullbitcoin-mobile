import 'dart:async';
import 'dart:io' show Platform;

import 'package:ark_wallet/ark_wallet.dart';
import 'package:bb_mobile/bloc_observer.dart';
import 'package:bb_mobile/core/background_tasks/handler.dart';
import 'package:bb_mobile/core/background_tasks/tasks.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/screens/app_init_error_screen.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/migration_reporter.dart';
import 'package:bb_mobile/core/utils/prefs_keys.dart';
import 'package:bb_mobile/core/utils/sentry_event_filter.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_startup/ui/app_startup_widget.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_listener.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_app.dart';
import 'package:bb_mobile/features/wizard/wizard_gate.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:bitbox_flutter/bitbox_flutter.dart';
import 'package:boltz/boltz.dart';
import 'package:dart_bbqr/bbqr.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lwk/lwk.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:payjoin_flutter/common.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

class Bull {
  /// Read by [SentryFlutter.init]'s `beforeSend` to decide whether a
  /// non-migration event should reach the server. Seeded from the wizard's
  /// pending answer or a [SharedPreferences] mirror before Sentry is up, then
  /// refreshed from the SQLite source of truth once the locator is ready.
  static bool _userConsent = false;

  static Future<void> init() async {
    await initLogs();
    _userConsent = await _readSeedConsent();
    // Populate the in-memory app-version holder BEFORE [initLocator] so
    // migration events fired from inside locator setup (FSS fallback,
    // drift schema migrations) carry from/to version tags.
    await _populateAppVersionContext();
    await initErrorReporting();
    await initFlutterRustBridgeDependencies();
    await initLocator();
    await applyWizardResult();
    _userConsent = await locator<SettingsRepository>().fetch().then(
      (s) => s.isErrorReportingEnabled,
    );
    await initWorkmanager();
    await _reportLaunchTransition();
  }

  /// Reads the best-known value for user consent before the locator is
  /// available. The wizard's pending answer wins when present (freshest);
  /// otherwise fall back to the [SharedPreferences] mirror written by
  /// `SettingsRepository.setErrorReportingEnabled` on previous launches.
  static Future<bool> _readSeedConsent() async {
    final pending = await WizardGate.readPending();
    if (pending != null) return pending.errorReporting;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(PrefsKeys.errorReportingEnabled) ?? false;
  }

  /// Flushes answers captured by the install/upgrade wizard (stored in
  /// [SharedPreferences] because the wizard runs before the locator is
  /// ready) into the SQLite settings repository, then marks the wizard as
  /// complete. Safe to call when no wizard answers are pending.
  static Future<void> applyWizardResult() async {
    final choices = await WizardGate.readPending();
    if (choices == null) return;
    final settings = locator<SettingsRepository>();
    await settings.setLanguage(choices.language);
    await settings.setThemeMode(choices.themeMode);
    await settings.setErrorReportingEnabled(choices.errorReporting);
    await WizardGate.clearPending();
    await WizardGate.markComplete();
  }

  static Future<void> initFlutterRustBridgeDependencies() async {
    final initTasks = [
      LibLwk.init(),
      BoltzCore.init(),
      PConfig.initializeApp(),
      LibBbqr.init(),
      LibArk.init(),
      if (Platform.isAndroid) BitBoxFlutterApi.initialize(),
    ];

    await Future.wait(initTasks);
  }

  static Future<void> initLogs() async {
    final logDirectory = await getApplicationDocumentsDirectory();
    log = Logger.init(directory: logDirectory);
    await log.ensureLogsExist();
  }

  static Future<void> initLocator() async {
    await AppLocator.setup(locator, SqliteDatabase());
    Bloc.observer = AppBlocObserver();
  }

  static Future<void> initWorkmanager() async {
    await Workmanager().initialize(backgroundTasksHandler);
    await Workmanager().cancelAll();
    await Workmanager().registerPeriodicTask(
      BackgroundTask.logsPrune.id,
      BackgroundTask.logsPrune.name,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        requiresBatteryNotLow: true,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
        requiresCharging: false,
      ),
    );
  }

  /// Populates [MigrationReporter.currentFromAppVersion] and
  /// [MigrationReporter.currentToAppVersion] so any migration event fired
  /// later in `Bull.init` (including FSS fallback and drift schema errors)
  /// carries from/to app-version tags. Does not touch Sentry or the
  /// persisted marker — that's [_reportLaunchTransition].
  static Future<void> _populateAppVersionContext() async {
    final info = await PackageInfo.fromPlatform();
    // Include the build number so within-version rebuilds (6.9.1+177 vs
    // 6.9.1+178) also register as upgrades.
    final current = '${info.version}+${info.buildNumber}';
    final prefs = await SharedPreferences.getInstance();
    MigrationReporter.currentFromAppVersion = prefs.getString(
      PrefsKeys.lastSeenAppVersion,
    );
    MigrationReporter.currentToAppVersion = current;
  }

  /// Fires one of two transition events at launch, then advances the
  /// persisted marker:
  ///
  /// - `fresh_install` — no previous version seen (first successful init
  ///   on this install). Carries `to_app_version` only.
  /// - `app_version_change` — previous version differs from current (any
  ///   direction: upgrade, downgrade, same-version rebuild). Carries both
  ///   `from_app_version` and `to_app_version`.
  ///
  /// The marker write is deferred until after the transition fires so a
  /// mid-init crash retries the event on the next launch.
  static Future<void> _reportLaunchTransition() async {
    final previous = MigrationReporter.currentFromAppVersion;
    final current = MigrationReporter.currentToAppVersion;
    if (current == null) return;
    if (previous == null) {
      await MigrationReporter.reportTransition(
        transitionType: 'fresh_install',
        toAppVersion: current,
      );
    } else if (previous != current) {
      await MigrationReporter.reportTransition(
        transitionType: 'app_version_change',
        fromAppVersion: previous,
        toAppVersion: current,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.lastSeenAppVersion, current);
  }

  static Future<void> initErrorReporting() async {
    await SentryFlutter.init((options) {
      options.dsn = kReleaseMode ? ApiServiceConstants.sentryDsn : '';
      options.compressPayload = true;

      // Set to true by default
      // SDK error reports — helps diagnose  issues.
      options.sendClientReports = true;
      // Crash counters per session
      options.enableAutoSessionTracking = true;

      // Depending on user consent to the reporting program
      options.enableAutoPerformanceTracing = _userConsent;
      options.tracesSampleRate = _userConsent ? 1.0 : 0;
      options.enableAutoNativeBreadcrumbs = _userConsent;

      // Set to false by default
      options.captureFailedRequests = false;
      options.enableUserInteractionBreadcrumbs = false;
      options.enableUserInteractionTracing = false;

      // Invariant lives in [filterSentryEvent] and is unit-tested. Migration
      // events (tagged `category=migration` via [MigrationReporter]) ALWAYS
      // reach Sentry regardless of [_userConsent]; everything else is gated.
      options.beforeSend = (event, hint) =>
          filterSentryEvent(event, userConsent: _userConsent);
    });
  }
}

Future main() async {
  await runZonedGuarded(
    () async {
      try {
        WidgetsFlutterBinding.ensureInitialized();
        if (await WizardGate.shouldShow()) {
          final completer = Completer<void>();
          runApp(
            WizardApp(
              onDone: (choices) async {
                await WizardGate.savePending(choices);
                completer.complete();
              },
            ),
          );
          await completer.future;
        }

        await Bull.init();
      } catch (error, stackTrace) {
        log.severe(error: error, trace: stackTrace);
        runApp(AppInitErrorScreen(error: error));
        return;
      }
      runApp(const BullBitcoinWalletApp());
    },
    (error, stackTrace) {
      log.severe(
        message: 'Global Unhandled Error',
        error: error,
        trace: stackTrace,
      );
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
  // final router = AppRouter.router;

  @override
  void initState() {
    super.initState();

    // Initialize the AppLifecycleListener class and pass callbacks
    _listener = AppLifecycleListener(onStateChange: _onStateChanged);
  }

  @override
  void dispose() {
    // Do not forget to dispose the listener
    _listener.dispose();

    super.dispose();
  }

  // Listen to the app lifecycle state changes
  void _onStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        _onDetached();
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.inactive:
        _onInactive();
      case AppLifecycleState.hidden:
        _onHidden();
      case AppLifecycleState.paused:
        _onPaused();
    }
  }

  void _onDetached() => log.info('detached');

  Future<void> _onResumed() async {
    log.info('resumed');
    try {
      await locator<RestartSwapWatcherUsecase>().execute();
    } catch (e) {
      log.severe(
        message: 'Error during app resume',
        error: e,
        trace: StackTrace.current,
      );
    }
  }

  void _onInactive() => log.info('inactive');

  void _onHidden() => log.info('hidden');

  void _onPaused() => log.info('paused');

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
                    debugShowCheckedModeBanner: false,
                    routerConfig: AppRouter.router,
                    theme: AppTheme.themeData(appThemeType),
                    locale: language?.locale,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (_, child) {
                      return AppStartupWidget(app: child!);
                    },
                  );
                },
              ),
        ),
      ),
    );
  }
}
