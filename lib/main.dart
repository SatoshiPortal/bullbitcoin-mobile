import 'dart:async';
import 'dart:developer';

import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/_ui/security_overlay.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/home/listeners.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/routes.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/listeners.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:lwk_dart/lwk_dart.dart';
import 'package:oktoast/oktoast.dart';

Future main({bool fromTest = false}) async {
  FlutterError.onError = (err) =>
      log('Flutter Error:' + err.toString(minLevel: DiagnosticLevel.warning));

  runZonedGuarded(() async {
    if (!fromTest) WidgetsFlutterBinding.ensureInitialized();
    await LibLwk.init();
    await LibBoltz.init();
    await dotenv.load(isOptional: true);
    Bloc.observer = BBlocObserver();
    // await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    await setupLocator(fromTest: fromTest);

    runApp(const BullBitcoinWalletApp());
  }, (error, stack) {
    log('\n\nError: $error \nStack: $stack\n\n');
  });
}

class BullBitcoinWalletApp extends StatelessWidget {
  const BullBitcoinWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: locator<SettingsCubit>()),
        BlocProvider.value(value: locator<Logger>()),
        BlocProvider.value(value: locator<Lighting>()),
        BlocProvider.value(value: locator<NetworkCubit>()),
        BlocProvider.value(value: locator<NetworkFeesCubit>()),
        BlocProvider.value(value: locator<CurrencyCubit>()),
        BlocProvider.value(value: locator<HomeCubit>()),
        BlocProvider.value(value: locator<WatchTxsBloc>()),
        // BlocProvider.value(value: TestCub()),
        BlocProvider.value(value: locator<NavName>()),
      ],
      child: BlocBuilder<Lighting, ThemeLighting>(
        builder: (context, lightingState) {
          return AnimatedSwitcher(
            duration: 600.ms,
            switchInCurve: Curves.easeInOutCubic,
            child: MaterialApp.router(
              theme: Themes.lightTheme,
              darkTheme: lightingState.dark(),
              themeMode: lightingState.mode(),
              routerConfig: locator<GoRouter>(),
              debugShowCheckedModeBanner: false,
              // localizationsDelegates: [localizationDelegate],
              // supportedLocales: localizationDelegate.supportedLocales,
              // locale: localizationDelegate.currentLocale,
              builder: (context, child) {
                // scheduleMicrotask(() async {
                //   await Future.delayed(100.ms);
                //   SystemChrome.setSystemUIOverlayStyle(
                //     SystemUiOverlayStyle(
                //       statusBarColor: context.colour.background,
                //     ),
                //   );
                // });
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                ]);
                if (child == null) return Container();
                return OKToast(
                  child: HomeWalletsSetupListener(
                    child: SwapAppListener(
                      child: GestureDetector(
                        onTap: () {
                          FocusScope.of(context).requestFocus(FocusNode());
                        },
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            textScaler: TextScaler.noScaling,
                          ),
                          child: AppLifecycleOverlay(
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
