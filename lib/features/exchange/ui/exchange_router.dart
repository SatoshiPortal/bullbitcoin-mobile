import 'dart:io';

import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_auth_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_home_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_kyc_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_landing_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_landing_screen_v2.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ExchangeRoute {
  exchangeHome('/exchange'),
  exchangeLanding('/exchange/landing'),
  exchangeAuth('/exchange/auth'),
  exchangeKyc('kyc');

  final String path;

  const ExchangeRoute(this.path);
}

class ExchangeRouter {
  static final routes = [
    GoRoute(
      name: ExchangeRoute.exchangeHome.name,
      path: ExchangeRoute.exchangeHome.path,
      redirect: (context, state) {
        final notLoggedIn = context.read<ExchangeCubit>().state.notLoggedIn;
        if (notLoggedIn) {
          return ExchangeRoute.exchangeLanding.path;
        }
        return null;
      },
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: const ExchangeHomeScreen(),
        );
      },
      routes: [
        GoRoute(
          name: ExchangeRoute.exchangeKyc.name,
          path: ExchangeRoute.exchangeKyc.path,
          builder: (context, state) {
            return const ExchangeKycScreen();
          },
        ),
      ],
    ),
    GoRoute(
      name: ExchangeRoute.exchangeLanding.name,
      path: ExchangeRoute.exchangeLanding.path,
      builder: (context, state) {
        // Show v2 screen for iOS, regular screen for Android
        if (Platform.isIOS) {
          return const ExchangeLandingScreenV2();
        }
        return const ExchangeLandingScreen();
      },
    ),
    GoRoute(
      name: ExchangeRoute.exchangeAuth.name,
      path: ExchangeRoute.exchangeAuth.path,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: BlocListener<ExchangeCubit, ExchangeState>(
            listenWhen:
                (previous, current) =>
                    previous.notLoggedIn && !current.notLoggedIn,
            listener: (context, state) {
              // Redirect to home screen if the API key becomes valid
              context.goNamed(ExchangeRoute.exchangeHome.name);
            },
            child: const ExchangeAuthScreen(),
          ),
        );
      },
    ),
  ];
}
