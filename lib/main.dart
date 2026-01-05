import 'dart:async';
import 'dart:io' show Platform;

import 'package:ark_wallet/ark_wallet.dart';
import 'package:bb_mobile/bloc_observer.dart';
import 'package:bb_mobile/core/background_tasks/handler.dart';
import 'package:bb_mobile/core/background_tasks/tasks.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/di.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_startup/ui/app_startup_widget.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/router.dart';
import 'package:bitbox_flutter/bitbox_flutter.dart';
import 'package:boltz/boltz.dart';
import 'package:dart_bbqr/bbqr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;
import 'package:lwk/lwk.dart';
import 'package:path_provider/path_provider.dart';
import 'package:payjoin_flutter/common.dart';
import 'package:workmanager/workmanager.dart';

class Bull {
  static Future<void> init() async {
    await initLogs();
    await initFlutterRustBridgeDependencies();

    // The Locator setup might depend on the initialization of the libraries above
    //  so it's important to call it after the initialization
    await initLocator();
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
    await initializeDependencies();
    Bloc.observer = AppBlocObserver();
  }
}

Future main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize the background tasks before anything else
      await Workmanager().initialize(backgroundTasksHandler);
      await Workmanager().cancelAll();

      await Bull.init();

      int delay = 0;
      for (final task in BackgroundTask.values) {
        await Workmanager().registerPeriodicTask(
          task.id,
          task.name,
          frequency: Duration(minutes: 15 + delay),
          constraints: Constraints(
            networkType: NetworkType.connected,
            requiresBatteryNotLow: true,
            requiresStorageNotLow: false,
            requiresDeviceIdle: false,
            requiresCharging: false,
          ),
        );
        delay++;
      }

      runApp(const BullBitcoinWalletApp());
    },
    (error, stack) {
      log.severe(error, trace: stack);
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
      await sl<RestartSwapWatcherUsecase>().execute();
    } catch (e) {
      log.severe('Error during app resume: $e');
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
        BlocProvider(create: (_) => sl<SettingsCubit>()..init()),
        BlocProvider(
          create: (_) => sl<AppStartupBloc>()..add(const AppStartupStarted()),
        ),
        BlocProvider(
          create: (_) =>
              sl<BitcoinPriceBloc>()..add(const BitcoinPriceStarted()),
        ),
        // Make the wallet bloc available to the whole app so environment changes
        // from anywhere (wallet or exchange tab) can trigger a re-fetch of the wallets.
        BlocProvider(create: (_) => sl<WalletBloc>()),
        // Make the exchange cubit available to the whole app so redirects
        // can use it to check if the user is authenticated
        BlocProvider(create: (_) => sl<ExchangeCubit>()),
      ],
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
    );
  }
}
