import 'dart:async';
import 'dart:developer';

import 'package:bb_mobile/bloc_observer.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_startup/ui/app_startup_widget.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:bip85/bip85.dart';
import 'package:boltz/boltz.dart';
import 'package:dart_bbqr/bbqr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;
import 'package:lwk/lwk.dart';
import 'package:payjoin_flutter/common.dart';

Future main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await Future.wait([
        LibLwk.init(),
        BoltzCore.init(),
        LibBip85.init(),
        PConfig.initializeApp(),
        dotenv.load(isOptional: true),
        LibBbqr.init(),
      ]);

      // The Locator setup might depend on the initialization of the libraries above
      //  so it's important to call it after the initialization

      await AppLocator.setup();
      Bloc.observer = AppBlocObserver();
      runApp(const BullBitcoinWalletApp());
    },
    (error, stack) {
      log('\n\nError: $error \nStack: $stack\n\n');
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

  void _onDetached() => debugPrint('detached');

  Future<void> _onResumed() async {
    debugPrint('resumed');
    try {
      await locator<RestartSwapWatcherUsecase>().execute();
      debugPrint('Restarted Swap Watcher!');
    } catch (e) {
      debugPrint('Error during app resume: $e');
    }
  }

  void _onInactive() => debugPrint('inactive');

  void _onHidden() => debugPrint('hidden');

  void _onPaused() => debugPrint('paused');

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
    );
  }
}
