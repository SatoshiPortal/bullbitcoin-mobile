import 'package:bb_mobile/app_locator.dart';
import 'package:bb_mobile/app_router.dart';
import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_startup/ui/app_startup_widget.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/fiat_currencies/presentation/bloc/fiat_currencies_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class BullBitcoinWalletApp extends StatefulWidget {
  const BullBitcoinWalletApp({super.key});

  @override
  State<BullBitcoinWalletApp> createState() => _BullBitcoinWalletAppState();
}

class _BullBitcoinWalletAppState extends State<BullBitcoinWalletApp> {
  late final AppLifecycleListener _listener;
  final router = AppRouter.router;

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
    locator<CheckPinCodeExistsUsecase>().execute().then((exists) {
      if (exists) {
        router.pushNamed(
          AppRoute.appUnlock.name,
          extra: () => router.pop(),
        );
      }
    });
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
          value: locator<FiatCurrenciesBloc>()
            ..add(
              const FiatCurrenciesStarted(),
            ),
        ),
      ],
      child: BlocSelector<SettingsCubit, Settings?, Language?>(
        selector: (settings) => settings?.language,
        builder: (context, language) => MaterialApp.router(
          title: 'BullBitcoin Wallet',
          routeInformationParser: router.routeInformationParser,
          routeInformationProvider: router.routeInformationProvider,
          routerDelegate: router.routerDelegate,
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
