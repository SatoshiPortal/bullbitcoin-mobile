import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/core/router/app_router.dart';
import 'package:bb_mobile/features/app_startup/app_startup_widget.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/fiat_currencies/presentation/bloc/fiat_currencies_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BullBitcoinWalletApp extends StatelessWidget {
  const BullBitcoinWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.router;

    return MultiBlocProvider(
      providers: [
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
      child: MaterialApp.router(
        title: 'BullBitcoin Wallet',
        routeInformationParser: router.routeInformationParser,
        routeInformationProvider: router.routeInformationProvider,
        routerDelegate: router.routerDelegate,
        builder: (_, child) {
          return AppStartupWidget(app: child!);
        },
      ),
    );
  }
}
