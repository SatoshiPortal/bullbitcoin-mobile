import 'dart:async';
import 'dart:io' show Platform;

import 'package:ark_wallet/ark_wallet.dart';
import 'package:bb_mobile/bloc_observer.dart';
import 'package:bb_mobile/core/background_tasks/handler.dart';
import 'package:bb_mobile/core/background_tasks/tasks.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_startup/ui/app_startup_widget.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_listener.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:bitbox_flutter/bitbox_flutter.dart';
import 'package:boltz/boltz.dart';
import 'package:dart_bbqr/bbqr.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;
import 'package:lwk/lwk.dart';
import 'package:path_provider/path_provider.dart';
import 'package:payjoin_flutter/common.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:workmanager/workmanager.dart';

class Bull {
  static Future<void> init() async {
    await initLogs();
    await initFlutterRustBridgeDependencies();

    // The Locator setup might depend on the initialization of the libraries above
    //  so it's important to call it after the initialization
    await initLocator();

    await initErrorReporting();
  }

  static Future<void> initFlutterRustBridgeDependencies() async {
    final initTasks = [
      dotenv.load(isOptional: true),
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

  static Future<void> initErrorReporting() async {
    // Error reports for users that gave consent in the app settings (default disabled)
    // Empty DSN if no consent or debug mode - Sentry won't send anything
    final isErrorReportingEnabled = await locator<SettingsRepository>()
        .fetch()
        .then((settings) => settings.isErrorReportingEnabled);
    final dsnSentry = isErrorReportingEnabled && kReleaseMode
        ? ApiServiceConstants.sentryDsn
        : ''; // "If an empty string is used, the SDK will not send any events."

    await SentryFlutter.init((options) {
      options.dsn = dsnSentry;
      options.compressPayload = true;
      options.beforeSend = (event, hint) {
        // Before sending the error report, anonymize the exception value
        // to avoid sending potentially sensitive information (txid, addresses…)
        final exceptions = event.exceptions;
        if (exceptions != null && exceptions.isNotEmpty) {
          final anonymizedExceptions = exceptions.map((e) {
            e.value = null;
            return e;
          }).toList();
          event.exceptions = anonymizedExceptions;
        }

        return event;
      };
    });
  }
}

Future main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Build expiration check
      final now = DateTime.now();
      final expirationTime = DateTime(
        2026,
        5,
        28,
        23,
        59,
      ); // Feb 28, 2026 at 11:59 PM
      if (now.isAfter(expirationTime)) {
        runApp(const BuildExpiredScreen());
        return;
      }

      // Initialize the background tasks before anything else
      await Workmanager().initialize(backgroundTasksHandler);
      await Workmanager().cancelAll();

      await Bull.init();

      await Workmanager().registerPeriodicTask(
        BackgroundTask.logsPrune.id,
        BackgroundTask.logsPrune.name,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
          requiresStorageNotLow: false,
          requiresDeviceIdle: false,
          requiresCharging: false,
        ),
      );

      runApp(const BullBitcoinWalletApp());
    },
    (error, stackTrace) async {
      log.severe(error: error, trace: stackTrace);
      runApp(
        BullBitcoinWalletAppInitErrorScreen(
          error: error,
          stackTrace: StackTrace.current,
        ),
      );
    },
  );
}

class BullBitcoinWalletAppInitErrorScreen extends StatelessWidget {
  const BullBitcoinWalletAppInitErrorScreen({
    super.key,
    required this.error,
    this.stackTrace,
  });

  final Object error;
  final StackTrace? stackTrace;

  Future<void> _shareLogs() async {
    try {
      final logs = await log.readLogs();
      await SharePlus.instance.share(
        ShareParams(
          text: logs.join('\n'),
          subject: 'bull_logs.tsv',
          title: 'bull_logs.tsv',
        ),
      );
    } catch (e) {
      // Silently fail if sharing logs doesn't work
      log.severe(
        message: 'Failed to share logs',
        error: e,
        trace: StackTrace.current,
      );
    }
  }

  Future<void> _clearLogs() async {
    try {
      await log.deleteLogs();
    } catch (e) {
      log.severe(
        message: 'Failed to clear logs',
        error: e,
        trace: StackTrace.current,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.themeData(AppThemeType.dark),
      home: Builder(
        builder: (context) {
          final colors = context.appColors;

          return Scaffold(
            backgroundColor: colors.background,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: colors.error, width: 2),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: colors.error,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'App Initialization Error',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: colors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Error:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainer,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: SelectableText(
                                error.toString(),
                                style: TextStyle(
                                  color: colors.error,
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (stackTrace != null) ...[
                              const SizedBox(height: 24),
                              Text(
                                'Stack Trace:',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: colors.text,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: SelectableText(
                                  stackTrace.toString(),
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _shareLogs,
                      icon: const Icon(Icons.share),
                      label: const Text('Share Logs'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: colors.surface,
                        foregroundColor: colors.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _clearLogs,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear Logs'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: colors.error,
                        foregroundColor: colors.onError,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
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

class BuildExpiredScreen extends StatelessWidget {
  const BuildExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.themeData(AppThemeType.dark),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 80),
              const SizedBox(height: 32),
              Text(
                'This release is expired',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
