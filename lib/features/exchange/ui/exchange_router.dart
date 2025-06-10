import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_auth_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_home_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ExchangeRoute {
  exchangeHome('/exchange'),
  exchangeAuth('/exchange/auth');

  final String path;

  const ExchangeRoute(this.path);
}

class ExchangeRouter {
  static final route = ShellRoute(
    builder: (context, state, child) {
      return BlocProvider(
        create: (context) => locator<ExchangeCubit>()..fetchUserSummary(),
        child: child,
      );
    },

    routes: [
      GoRoute(
        name: ExchangeRoute.exchangeHome.name,
        path: ExchangeRoute.exchangeHome.path,
        builder: (BuildContext context, GoRouterState state) {
          return BlocListener<ExchangeCubit, ExchangeState>(
            listenWhen:
                (previous, current) =>
                    !previous.isApiKeyInvalid && current.isApiKeyInvalid,
            listener: (context, state) {
              context.goNamed(ExchangeRoute.exchangeAuth.name);
            },
            child: const ExchangeHomeScreen(),
          );
        },
      ),
      GoRoute(
        name: ExchangeRoute.exchangeAuth.name,
        path: ExchangeRoute.exchangeAuth.path,
        builder: (context, state) {
          return BlocListener<ExchangeCubit, ExchangeState>(
            listenWhen:
                (previous, current) =>
                    previous.isApiKeyInvalid && !current.isApiKeyInvalid,
            listener: (context, state) {
              context.goNamed(ExchangeRoute.exchangeHome.name);
            },
            child: const ExchangeAuthScreen(),
          );
        },
      ),
    ],
  );
}
