import 'package:bull_ui/bull_ui.dart'
    show BullScaffold, BullTopBar, BullButton, BullText, Gap, BullTypographyX;
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';

import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_auth_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_home_screen.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_exit_on_back.dart';
import 'package:exchange/exchange.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ExchangeRoute {
  exchangeHome('/exchange'),
  exchangeAuth('/exchange/auth');

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
  final Future<Result<ExchangeKycConfiguration, ExchangeFailure>> Function()?
  loadKyc;

  const ExchangeRouterConfig({
    required this.networkUnavailable,
    required this.isSuperuser,
    required this.homePath,
    required this.buildHomeCards,
    required this.onHomeRefresh,
    required this.onExit,
    required this.onOpenSettings,
    required this.onAction,
    this.loadKyc,
  });
}

class ExchangeRouter {
  static List<RouteBase> routes(
    ExchangeRouterConfig config, {
    BullExchangeFeature? exchangeFeature,
  }) {
    final feature = exchangeFeature ?? mount(config);
    return [
      GoRoute(
        name: ExchangeRoute.exchangeHome.name,
        path: ExchangeRoute.exchangeHome.path,
        redirect: (context, state) async {
          if (await config.networkUnavailable()) return config.homePath;
          if (!context.mounted) return null;
          final notLoggedIn = !ExchangeScope.isLoggedIn(context);
          if (notLoggedIn) {
            return BullExchangeNavigation.landingPath;
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
              listenWhen: (wasLoggedIn, isLoggedIn) =>
                  wasLoggedIn && !isLoggedIn,
              listener: (context, _) {
                if (ExchangeScope.isEnabled(context)) {
                  BullExchangeNavigation.goToLanding(context);
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
        routes: [?feature.kycRoute],
      ),
      ...feature.routes,
    ];
  }

  static BullExchangeFeature mount(
    ExchangeRouterConfig config, {
    Exchange Function()? exchange,
    ExchangeSettingsHost? settings,
  }) => BullExchangeFeature.mount(
    networkUnavailable: config.networkUnavailable,
    showWebsiteOnly: (context) =>
        Platform.isIOS && !config.isSuperuser(context),
    unavailableRedirectPath: config.homePath,
    brandAssetPath: Assets.logos.bbLogoSmall.path,
    copy: (context) {
      final loc = context.loc;
      return ExchangeLandingCopy(
        brandName: loc.exchangeBrandName,
        connectAccount: loc.exchangeLandingConnectAccount,
        recommendedExchange: loc.exchangeLandingRecommendedExchange,
        selfCustody: loc.exchangeFeatureSelfCustody,
        recurringOrders: loc.exchangeFeatureDcaOrders,
        sellBitcoin: loc.exchangeFeatureSellBitcoin,
        bankTransfers: loc.exchangeFeatureBankTransfers,
        customerSupport: loc.exchangeFeatureCustomerSupport,
        unifiedHistory: loc.exchangeFeatureUnifiedHistory,
        legalDisclaimer: loc.exchangeLandingDisclaimerLegal,
        unavailableDisclaimer: loc.exchangeLandingDisclaimerNotAvailable,
        signIn: loc.exchangeLoginButton,
        openWebsite: loc.exchangeGoToWebsiteButton,
      );
    },
    onSignIn: (context) => context.goNamed(ExchangeRoute.exchangeAuth.name),
    onExit: config.onExit,
    settings: settings,
    kyc: switch (config.loadKyc) {
      final load? => ExchangeKycHost(
        loadConfiguration: load,
        failureMessage: (context, failure) => failure.toTranslated(context),
        onExit: (context) {
          unawaited(context.read<ExchangeCubit>().fetchUserSummary());
          context.pop();
        },
      ),
      null => null,
    },
    supportChat: exchange == null
        ? null
        : (
            exchange: exchange,
            isLoggedIn: ExchangeScope.isLoggedIn,
            enableLogin: (context) =>
                context.read<ExchangeCubit>().enableForSupport(),
            onLogin: (context, draft) => context.goNamed(
              ExchangeRoute.exchangeAuth.name,
              queryParameters: {'from': 'support'},
              extra: draft,
            ),
            loginLabel: (context) => context.loc.exchangeLoginButton,
            failureMessage: (context, failure) => failure.toTranslated(context),
            onExit: (context, fromExchange) {
              if (fromExchange) {
                context.goNamed(ExchangeRoute.exchangeHome.name);
              } else {
                config.onExit(context);
              }
            },
          ),
  );

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
                    ExchangeSupportChatNavigation.routeName,
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
              BullButton.primary(
                label: context.loc.exchangeTradingRetry,
                onPressed: () => context.read<ExchangeCubit>().retryAccess(),
              ),
            ],
          ),
        ),
      );
    },
  );
}
