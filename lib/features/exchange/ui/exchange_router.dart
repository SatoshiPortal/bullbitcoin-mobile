import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_session.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_auth_screen.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_actions.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_home_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_kyc_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_landing_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_landing_screen_v2.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_support_login_screen.dart';
import 'package:bb_mobile/features/exchange_support_chat/public/exchange_support_chat_facade.dart';
import 'package:flutter/material.dart';
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

class ExchangeRouterConfig {
  final bool Function(BuildContext) isSuperuser;
  final String homePath;
  final List<Widget> Function() buildHomeCards;
  final VoidCallback onHomeRefresh;
  final void Function(BuildContext) onExit;
  final void Function(BuildContext) onOpenSettings;
  final void Function(BuildContext, ExchangeHomeAction) onAction;

  const ExchangeRouterConfig({
    required this.isSuperuser,
    required this.homePath,
    required this.buildHomeCards,
    required this.onHomeRefresh,
    required this.onExit,
    required this.onOpenSettings,
    required this.onAction,
  });
}

class ExchangeRouter {
  static GoRoute supportChatRoute(ExchangeRouterConfig config) =>
      ExchangeSupportChatRouter.route(
        isLoggedIn: (context) => context.read<ExchangeCubit>().state.hasUser,
        loginScreenBuilder: (draft) => ExchangeSupportLoginScreen(draft: draft),
        onExit: (context, fromExchange) {
          if (fromExchange) {
            context.goNamed(ExchangeRoute.exchangeHome.name);
          } else {
            config.onExit(context);
          }
        },
      );

  static List<RouteBase> routes(ExchangeRouterConfig config) => [
    GoRoute(
      name: ExchangeRoute.exchangeHome.name,
      path: ExchangeRoute.exchangeHome.path,
      redirect: (context, state) {
        final notLoggedIn = context.read<ExchangeCubit>().state.notLoggedIn;
        if (notLoggedIn) {
          return ExchangeRoute.exchangeLanding.path;
        }
        if (Platform.isIOS && !config.isSuperuser(context)) {
          return config.homePath;
        }
        return null;
      },
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: ExchangeHomeScreen(
            homeCards: config.buildHomeCards(),
            onHomeRefresh: config.onHomeRefresh,
            onOpenSettings: () => config.onOpenSettings(context),
            onAction: (action) => config.onAction(context, action),
          ),
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
      pageBuilder: (context, state) {
        // Show v2 screen for iOS without superuser, v1 for iOS with superuser, regular screen for Android
        void onExit() => config.onExit(context);
        Widget landingScreen;
        if (Platform.isIOS) {
          if (config.isSuperuser(context)) {
            landingScreen = ExchangeLandingScreen(onExit: onExit);
          } else {
            landingScreen = ExchangeLandingScreenV2(onExit: onExit);
          }
        } else {
          landingScreen = ExchangeLandingScreen(onExit: onExit);
        }

        return NoTransitionPage(key: state.pageKey, child: landingScreen);
      },
    ),
    GoRoute(
      name: ExchangeRoute.exchangeAuth.name,
      path: ExchangeRoute.exchangeAuth.path,
      pageBuilder: (context, state) {
        final draft = state.extra as ExchangeSupportChatDraft?;
        final fromSupport = state.uri.queryParameters['from'] == 'support';
        final fromSettings = state.uri.queryParameters['from'] == 'settings';
        if (fromSettings) {
          return NoTransitionPage(
            key: state.pageKey,
            child: _SettingsAuthenticationReturn(
              onExit: () => config.onExit(context),
              child: ExchangeAuthScreen(onExit: () => config.onExit(context)),
            ),
          );
        }
        return NoTransitionPage(
          key: state.pageKey,
          child: BlocListener<ExchangeCubit, ExchangeState>(
            listenWhen: (previous, current) =>
                previous.notLoggedIn && !current.notLoggedIn,
            listener: (context, exchangeState) {
              if (fromSupport) {
                final isIOSNonSuperuser =
                    Platform.isIOS && !config.isSuperuser(context);
                context.goNamed(
                  ExchangeSupportChatFacade.routeName,
                  queryParameters: isIOSNonSuperuser
                      ? {}
                      : {'from': 'exchange'},
                  extra: draft,
                );
                return;
              }
              if (Platform.isIOS && !config.isSuperuser(context)) {
                config.onExit(context);
                return;
              }
              context.goNamed(ExchangeRoute.exchangeHome.name);
            },
            child: ExchangeAuthScreen(onExit: () => config.onExit(context)),
          ),
        );
      },
    ),
  ];
}

class _SettingsAuthenticationReturn extends StatefulWidget {
  const _SettingsAuthenticationReturn({
    required this.child,
    required this.onExit,
  });

  final Widget child;
  final VoidCallback onExit;

  @override
  State<_SettingsAuthenticationReturn> createState() =>
      _SettingsAuthenticationReturnState();
}

class _SettingsAuthenticationReturnState
    extends State<_SettingsAuthenticationReturn> {
  StreamSubscription<ExchangeSessionStatus>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = locator<ExchangeSession>().watch().listen((status) {
      if (mounted && status == ExchangeSessionStatus.authenticated) {
        widget.onExit();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
