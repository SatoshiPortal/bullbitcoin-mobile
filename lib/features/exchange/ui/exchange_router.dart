import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_auth_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_home_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ExchangeRoute {
  exchangeHome('/exchange'),
  exchangeAuth('/exchange/auth');

  final String path;

  const ExchangeRoute(this.path);
}

class ExchangeRouter {
  static final routes = [
    GoRoute(
      name: ExchangeRoute.exchangeHome.name,
      path: ExchangeRoute.exchangeHome.path,
      redirect: (context, state) {
        // Redirect to auth screen if API key is invalid
        final isApiKeyInvalid =
            context.read<ExchangeCubit>().state.isApiKeyInvalid;
        if (isApiKeyInvalid) {
          return ExchangeRoute.exchangeAuth.path;
        }
        return null;
      },
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: BlocListener<ExchangeCubit, ExchangeState>(
            listenWhen:
                (previous, current) =>
                    !previous.isApiKeyInvalid && current.isApiKeyInvalid,
            listener: (context, state) {
              // Redirect to auth screen if the API key becomes invalid
              context.goNamed(ExchangeRoute.exchangeAuth.name);
            },
            child: const ExchangeHomeScreen(),
          ),
        );
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
                    previous.isApiKeyInvalid && !current.isApiKeyInvalid,
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
