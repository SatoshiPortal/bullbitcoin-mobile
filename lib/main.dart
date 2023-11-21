import 'package:bb_mobile/_pkg/i18n.dart';
import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/deep_linking.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/network_fees_cubit.dart';
import 'package:bb_mobile/routes.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_state.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_translate/flutter_translate.dart';

Future main({bool fromTest = false}) async {
  await dotenv.load(isOptional: true);
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = BBlocObserver();

  await setupLocator(fromTest: fromTest);
  final delegate = await Localise.getDelegate();

  runApp(
    LocalizedApp(
      delegate,
      const BullBitcoinWalletApp(),
    ),
  );
}

class BullBitcoinWalletApp extends StatelessWidget {
  const BullBitcoinWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localizationDelegate = LocalizedApp.of(context).delegate;

    return LocalizationProvider(
      state: LocalizationProvider.of(context).state,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: locator<SettingsCubit>()),
          BlocProvider.value(value: locator<Logger>()),
          BlocProvider.value(value: locator<Lighting>()),
          BlocProvider.value(value: locator<NetworkCubit>()),
          BlocProvider.value(value: locator<NetworkFeesCubit>()),
          BlocProvider.value(value: locator<CurrencyCubit>()),
        ],
        child: BlocListener<SettingsCubit, SettingsState>(
          listener: (context, state) {
            if (state.language != localizationDelegate.currentLocale.languageCode)
              localizationDelegate.changeLocale(Locale(state.language ?? 'en'));
          },
          child: DeepLinker(
            child: BlocBuilder<Lighting, ThemeLighting>(
              builder: (context, state) {
                return AnimatedSwitcher(
                  duration: 600.ms,
                  switchInCurve: Curves.easeInOutCubic,
                  child: MaterialApp.router(
                    theme: Themes.lightTheme,
                    darkTheme: state.dark(),
                    themeMode: state.mode(),
                    routerConfig: router,
                    debugShowCheckedModeBanner: false,
                    localizationsDelegates: [
                      localizationDelegate,
                    ],
                    supportedLocales: localizationDelegate.supportedLocales,
                    locale: localizationDelegate.currentLocale,
                    builder: (context, child) {
                      SystemChrome.setSystemUIOverlayStyle(
                        SystemUiOverlayStyle(
                          statusBarColor: context.colour.background,
                        ),
                      );
                      if (child == null) return Container();
                      return GestureDetector(
                        onTap: () {
                          FocusScope.of(context).requestFocus(FocusNode());
                        },
                        child: AppLifecycleOverlay(child: child),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class AppLifecycleOverlay extends StatefulWidget {
  const AppLifecycleOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<AppLifecycleOverlay> createState() => _AppLifecycleOverlayState();
}

class _AppLifecycleOverlayState extends State<AppLifecycleOverlay> with WidgetsBindingObserver {
  bool shouldBlur = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      // if (!kDebugMode)
      shouldBlur = state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.detached;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colour.primary,
      child: AnimatedOpacity(
        duration: 300.ms,
        opacity: shouldBlur ? 0 : 1,
        child: widget.child,
      ),
    );
  }
}
