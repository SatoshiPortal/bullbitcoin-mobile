import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/core/router/app_router.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_startup/presentation/widgets/app_startup_widget.dart';
import 'package:bb_mobile/features/fiat_currencies/presentation/bloc/fiat_currencies_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

    // Trigger the "resumed" logic on startup as well
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _onResumed();
      }
    });
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
    router.pushNamed(AppRoute.unlock.name);
  }

  void _onInactive() => debugPrint('inactive');

  void _onHidden() => debugPrint('hidden');

  void _onPaused() => debugPrint('paused');

  @override
  Widget build(BuildContext context) {
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
