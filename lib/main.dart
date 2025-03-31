import 'dart:async';
import 'dart:developer';

import 'package:bb_mobile/bloc_observer.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lwk/lwk.dart';
import 'package:payjoin_flutter/common.dart';

Future main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Future.wait([
      Hive.initFlutter(),
      LibLwk.init(),
      BoltzCore.init(),
      LibBip85.init(),
      PConfig.initializeApp(),
      dotenv.load(isOptional: true),
    ]);

    // The Locator setup might depend on the initialization of the libraries above
    //  so it's important to call it after the initialization
    await AppLocator.setup();

    Bloc.observer = AppBlocObserver();

    runApp(const BullBitcoinWalletApp());
  }, (error, stack) {
    log('\n\nError: $error \nStack: $stack\n\n');
  });
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
    _listener = AppLifecycleListener(
      onStateChange: _onStateChanged,
    );
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

  void _onResumed() {
    debugPrint('resumed');
    // locator<CheckPinCodeExistsUsecase>().execute().then((exists) {
    //   if (exists) {
    //     AppRouter.router.pushNamed(
    //       AppRoute.appUnlock.name,
    //       extra: () => AppRouter.router.pop(),
    //     );
    //   }
    // });
  }

  void _onInactive() => debugPrint('inactive');

  void _onHidden() => debugPrint('hidden');

  void _onPaused() => debugPrint('paused');

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(
          value: locator<SettingsCubit>()..init(),
        ),
        BlocProvider.value(
          value: locator<AppStartupBloc>()
            ..add(
              const AppStartupStarted(),
            ),
        ),
        BlocProvider.value(
          value: locator<BitcoinPriceBloc>()
            ..add(
              const BitcoinPriceStarted(),
            ),
        ),
      ],
      child: BlocSelector<SettingsCubit, SettingsState?, Language?>(
        selector: (settings) => settings?.language,
        builder: (context, language) => MaterialApp.router(
          title: 'BullBitcoin Wallet',
          debugShowCheckedModeBanner: false,
          routerConfig: AppRouter.router,
          // routeInformationParser: router.routeInformationParser,
          // routeInformationProvider: router.routeInformationProvider,
          // routerDelegate: router.routerDelegate,
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
