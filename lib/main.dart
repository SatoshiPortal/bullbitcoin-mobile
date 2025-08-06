import 'dart:async';

import 'package:bb_mobile/bloc_observer.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_startup/ui/app_startup_widget.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:bip85/bip85.dart';
import 'package:boltz/boltz.dart';
import 'package:dart_bbqr/bbqr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;
import 'package:lwk/lwk.dart';
import 'package:path_provider/path_provider.dart';
import 'package:payjoin_flutter/common.dart';

class Bull {
  static Future<void> init() async {
    await Future.wait([
      LibLwk.init(),
      BoltzCore.init(),
      LibBip85.init(),
      PConfig.initializeApp(),
      dotenv.load(isOptional: true),
      LibBbqr.init(),
    ]);

    final logDirectory = await getApplicationDocumentsDirectory();
    log = Logger.init(directory: logDirectory);

    // The Locator setup might depend on the initialization of the libraries above
    //  so it's important to call it after the initialization
    await AppLocator.setup();
    Bloc.observer = AppBlocObserver();
  }
}

Future main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Bull.init();
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
      await locator<RestartSwapWatcherUsecase>().execute();
    } catch (e) {
      log.severe('Error during app resume: $e');
    }
  }

  void _onInactive() => log.info('inactive');

  void _onHidden() => log.info('hidden');

  void _onPaused() => log.info('paused');

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => locator<SettingsCubit>()..init()),
        BlocProvider(
          create:
              (_) => locator<AppStartupBloc>()..add(const AppStartupStarted()),
        ),
        BlocProvider(
          create:
              (_) =>
                  locator<BitcoinPriceBloc>()..add(const BitcoinPriceStarted()),
        ),
        // Make the wallet bloc available to the whole app so environment changes
        // from anywhere (wallet or exchange tab) can trigger a re-fetch of the wallets.
        BlocProvider(create: (_) => locator<WalletBloc>()),
        // Make the exchange cubit available to the whole app so redirects
        // can use it to check if the user is authenticated and also to fetch
        // the user summary when the environment changes from anywhere in the app.
        BlocProvider(
          create: (_) => locator<ExchangeCubit>()..fetchUserSummary(),
        ),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<AppStartupBloc, AppStartupState>(
            listenWhen:
                (previous, current) =>
                    previous != current &&
                    current is AppStartupSuccess &&
                    current.hasDefaultWallets,
            listener: (context, settings) {
              // If wallets exist and the app has started successfully,
              // we can start the wallet bloc to fetch the wallets.
              context.read<WalletBloc>().add(const WalletStarted());
              context.read<WalletBloc>().add(const CheckAllWarnings());
            },
          ),
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen:
                (previous, current) =>
                    previous.environment != current.environment,
            listener: (context, settings) async {
              // Re-fetch user summary (re-init exchange bloc) and wallets
              //  when environment changes
              context.read<WalletBloc>().add(const WalletStarted());
              await context.read<ExchangeCubit>().fetchUserSummary();
            },
          ),
        ],
        child: BlocSelector<SettingsCubit, SettingsState, Language?>(
          selector: (settings) => settings.language,
          builder:
              (context, language) => MaterialApp.router(
                title: 'BullBitcoin Wallet',
                debugShowCheckedModeBanner: false,
                routerConfig: AppRouter.router,
                theme: AppTheme.themeData(AppThemeType.light),
                locale: language?.locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (_, child) {
                  return AppStartupWidget(app: child!);
                },
              ),
        ),
      ),
    );
  }
}
