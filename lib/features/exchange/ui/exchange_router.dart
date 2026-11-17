import 'package:bull_ui/bull_ui.dart'
    show
        BullScaffold,
        BullTopBar,
        BullButton,
        BullText,
        BullThemeX,
        Gap,
        BullTypographyX;
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';

import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_auth_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_home_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_kyc_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_landing_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_landing_screen_v2.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_support_login_screen.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_exit_on_back.dart';
import 'package:bb_mobile/features/exchange_support_chat/public/exchange_support_chat_facade.dart';
import 'package:material_ui/material_ui.dart';
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
  final Future<bool> Function() networkUnavailable;
  final bool Function(BuildContext) isSuperuser;
  final String homePath;
  final List<Widget> Function() buildHomeCards;
  final VoidCallback onHomeRefresh;
  final void Function(BuildContext) onExit;
  final void Function(BuildContext) onOpenSettings;
  final void Function(BuildContext, ExchangeHomeAction) onAction;

  const ExchangeRouterConfig({
    required this.networkUnavailable,
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
        isLoggedIn: (context) => ExchangeScope.isLoggedIn(context),
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
      redirect: (context, state) async {
        if (await config.networkUnavailable()) return config.homePath;
        if (!context.mounted) return null;
        final notLoggedIn = !ExchangeScope.isLoggedIn(context);
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
          // Redirects run only on navigation: a session that ends while Trade
          // is open must still leave it. Sign-in is offered only while access
          // stays enabled; sign-out turns access off and returns home.
          child: ExchangeSessionListener(
            listenWhen: (wasLoggedIn, isLoggedIn) => wasLoggedIn && !isLoggedIn,
            listener: (context, _) {
              if (ExchangeScope.isEnabled(context)) {
                context.goNamed(ExchangeRoute.exchangeLanding.name);
              } else {
                config.onExit(context);
              }
            },
            child: ExchangeHomeScreen(
              homeCards: config.buildHomeCards(),
              onHomeRefresh: config.onHomeRefresh,
              onOpenSettings: () => config.onOpenSettings(context),
              onAction: (action) => config.onAction(context, action),
              onExit: () => config.onExit(context),
            ),
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
      redirect: (context, state) async =>
          await config.networkUnavailable() ? config.homePath : null,
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
  ];

  static GoRoute authRoute(ExchangeRouterConfig config) => GoRoute(
    name: ExchangeRoute.exchangeAuth.name,
    path: ExchangeRoute.exchangeAuth.path,
    redirect: (context, state) async =>
        await config.networkUnavailable() ? config.homePath : null,
    pageBuilder: (context, state) {
      final draft = state.extra as ExchangeSupportChatDraft?;
      final fromSupport = state.uri.queryParameters['from'] == 'support';
      final fromSettings = state.uri.queryParameters['from'] == 'settings';
      if (fromSettings) {
        void exitSettingsAuth() {
          if (context.canPop()) {
            context.pop();
          } else {
            config.onExit(context);
          }
        }

        return NoTransitionPage(
          key: state.pageKey,
          child: _AuthAccessGate(
            config: config,
            child: _SettingsAuthenticationReturn(
              onExit: exitSettingsAuth,
              child: Scaffold(
                body: ExchangeAuthScreen(onExit: exitSettingsAuth),
              ),
            ),
          ),
        );
      }
      // Support and the landing page open sign-in with `go`, which leaves
      // nothing to go back to.
      return NoTransitionPage(
        key: state.pageKey,
        child: ExchangeExitOnBack(
          onExit: () => config.onExit(context),
          child: _AuthAccessGate(
            config: config,
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
              child: Scaffold(
                body: ExchangeAuthScreen(onExit: () => config.onExit(context)),
              ),
            ),
          ),
        ),
      );
    },
  );
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
  StreamSubscription<ExchangeAccess>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ExchangeScope.accessChanges().listen((status) {
      if (mounted &&
          status is ExchangeAccessEnabled &&
          status.session == ExchangeAccessSession.signedIn) {
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

class _AuthAccessGate extends StatelessWidget {
  const _AuthAccessGate({required this.config, required this.child});
  final ExchangeRouterConfig config;
  final Widget child;
  @override
  Widget build(BuildContext context) => ExchangeAccessBuilder(
    builder: (context, access) {
      if (ExchangeAvailability.canAuthenticate(access)) {
        return child;
      }
      return BullScaffold(
        body: SafeArea(
          child: Column(
            children: [
              BullTopBar(
                title: context.loc.exchangeAccessSettingsTitle,
                onBack: () => config.onExit(context),
              ),
              const Gap(24),
              BullText(
                context.loc.exchangeTradingUnavailable,
                style: context.bullType.body,
              ),
              const Gap(16),
              BullButton.big(
                label: context.loc.exchangeTradingRetry,
                bgColor: context.bull.primary,
                textColor: context.bull.onPrimary,
                onPressed: () => context.read<ExchangeCubit>().retryAccess(),
              ),
            ],
          ),
        ),
      );
    },
  );
}
