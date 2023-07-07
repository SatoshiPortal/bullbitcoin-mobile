import 'package:bb_mobile/_pkg/i18n.dart';
import 'package:bb_mobile/home/deep_linking.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/routes.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_state.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_translate/flutter_translate.dart';

Future main({bool fromTest = false}) async {
  await dotenv.load(isOptional: true);
  WidgetsFlutterBinding.ensureInitialized();
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
      child: BlocProvider.value(
        value: locator<SettingsCubit>(),
        child: BlocListener<SettingsCubit, SettingsState>(
          listener: (context, state) {
            if (state.language !=
                localizationDelegate.currentLocale.languageCode)
              localizationDelegate.changeLocale(Locale(state.language ?? 'en'));
          },
          child: DeepLinker(
            child: MaterialApp.router(
              theme: Themes.lightTheme,
              darkTheme: Themes.darkTheme,
              themeMode: ThemeMode.light,
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
                  child: child,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
