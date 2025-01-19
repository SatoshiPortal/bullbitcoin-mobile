import 'package:bb_mobile/core/router/route_error_screen.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/pin_code/presentation/flows/pin_code_setting_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

enum AppRoute {
  landing('/landing'),
  home('/home'),
  settings('/settings'),
  receive('/receive'),
  send('/send');

  final String path;

  const AppRoute(this.path);
}

class AppRouter {
  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoute.landing.path,
    routes: [
      GoRoute(
        name: AppRoute.landing.name,
        path: AppRoute.landing.path,
        redirect: (context, state) {
          // Check AppStartupState to skip landing if user has existing wallets
          final appStartupState = context.read<AppStartupBloc>().state;
          if (appStartupState is AppStartupSuccess &&
              appStartupState.hasExistingWallets) {
            return AppRoute.home.path;
          }
          // Redirect to settings page to showcase pin code feature for now,
          //  normally should redirect to landing page by returning null
          return AppRoute.settings.path;
          // return null;
        },
        builder: (context, state) => const Text('Landing'),
      ),
      GoRoute(
        name: AppRoute.home.name,
        path: AppRoute.home.path,
        builder: (context, state) => const Text('Home'),
      ),
      GoRoute(
        name: AppRoute.settings.name,
        path: AppRoute.settings.path,
        builder: (context, state) =>
            const PinCodeSettingFlow(), // Todo: Replace with base Settings screen once PinCode feature is showcased
      ),
      GoRoute(
        name: AppRoute.receive.name,
        path: AppRoute.receive.path,
        builder: (context, state) => const Text('Receive'),
      ),
      GoRoute(
        name: AppRoute.send.name,
        path: AppRoute.send.path,
        builder: (context, state) => const Text('Send'),
      ),
    ],
    errorBuilder: (context, state) => const RouteErrorScreen(),
  );
}
