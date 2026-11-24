import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:primitives/primitives.dart';

import 'autobuy/autobuy_mount.dart';
import 'dashboard/exchange_dashboard_route.dart';
import 'auth/exchange_auth_route.dart';
import 'auth/exchange_auth_screen.dart';
import 'exchange_landing_copy.dart';
import 'exchange_landing_navigation.dart';
import 'exchange_purchase_routes.dart';
import 'funding/fund_exchange_router.dart';
import 'kyc/exchange_kyc_host.dart';
import 'kyc/exchange_kyc_screen.dart';
import 'limit_orders/limit_order_creation_route.dart';
import 'limit_orders/limit_orders_management.dart';
import 'pay/mount_pay.dart';
import 'payin/exchange_payin_host.dart';
import 'sell/mount_sell.dart';
import 'settings/ui/exchange_settings_router.dart';
import 'support_chat/exchange_support_chat_navigation.dart';
import 'support_chat/ui/exchange_support_chat_router.dart';
import 'ui/screens/exchange_landing_screen.dart';
import 'ui/screens/exchange_landing_screen_v2.dart';
import 'withdraw/ui/withdraw_router.dart';

typedef ExchangeSupportChatHost = ({
  Exchange Function() exchange,
  bool Function(BuildContext) isLoggedIn,
  Future<Result<void, ExchangeFailure>> Function(BuildContext) enableLogin,
  void Function(BuildContext, ExchangeSupportChatDraft?) onLogin,
  String Function(BuildContext) loginLabel,
  String Function(BuildContext, ExchangeFailure) failureMessage,
  void Function(BuildContext, bool fromExchange) onExit,
  void Function(BuildContext) onMessagesRead,
});

/// Mounts Exchange routes in their host's navigation slots.
final class BullExchangeFeature {
  final List<RouteBase> routes;
  final GoRoute? supportChatRoute;
  final GoRoute? kycRoute;
  final List<RouteBase> settingsRoutes;
  final List<RouteBase> fundingRoutes;
  final GoRoute? autoBuy;
  final GoRoute? authRoute;
  final GoRoute? dashboardRoute;
  final GoRoute? withdrawalRoute;
  final GoRoute? limitOrderDetails;
  final GoRoute? limitOrderCreate;
  final List<RouteBase> buyRoutes;
  final GoRoute? dcaRoute;
  final ShellRoute? sellRoute;
  final ShellRoute? payRoute;

  const BullExchangeFeature._(
    this.routes,
    this.supportChatRoute,
    this.kycRoute,
    this.settingsRoutes,
    this.fundingRoutes,
    this.autoBuy,
    this.authRoute,
    this.dashboardRoute,
    this.withdrawalRoute,
    this.limitOrderDetails,
    this.limitOrderCreate,
    this.buyRoutes,
    this.dcaRoute,
    this.sellRoute,
    this.payRoute,
  );

  static BullExchangeFeature mount({
    required Future<bool> Function() networkUnavailable,
    required bool Function(BuildContext) showWebsiteOnly,
    required String unavailableRedirectPath,
    required String brandAssetPath,
    required void Function(BuildContext) onExit,
    ExchangeSupportChatHost? supportChat,
    ExchangeKycHost? kyc,
    ExchangeSettingsHost? settings,
    ExchangeFundingHost? funding,
    AutoBuyHost? autoBuy,
    ExchangeAuthHost? auth,
    ExchangeDashboardHost? dashboard,
    ExchangeWithdrawalHost? withdrawal,
    Exchange Function()? limitOrders,
    ExchangePurchaseHost? purchases,
    ExchangePayinHost? payins,
  }) {
    final kycRoute = kyc == null
        ? null
        : GoRoute(
            name: BullExchangeNavigation.kycName,
            path: 'kyc',
            builder: (_, _) => ExchangeKycScreen(host: kyc),
          );
    return BullExchangeFeature._(
      List.unmodifiable([
        GoRoute(
          name: BullExchangeNavigation.landingName,
          path: BullExchangeNavigation.landingPath,
          redirect: (_, _) async =>
              await networkUnavailable() ? unavailableRedirectPath : null,
          pageBuilder: (context, state) {
            final labels = ExchangeLandingCopy.of(context);
            void exit() => onExit(context);
            return NoTransitionPage(
              key: state.pageKey,
              child: showWebsiteOnly(context)
                  ? ExchangeLandingScreenV2(
                      copy: labels,
                      brandAssetPath: brandAssetPath,
                      onExit: exit,
                    )
                  : ExchangeLandingScreen(
                      copy: labels,
                      brandAssetPath: brandAssetPath,
                      onSignIn: () =>
                          context.goNamed(BullExchangeNavigation.authName),
                      onExit: exit,
                    ),
            );
          },
        ),
      ]),
      supportChat == null
          ? null
          : ExchangeSupportChatRouter.route(
              exchange: supportChat.exchange,
              isLoggedIn: supportChat.isLoggedIn,
              enableLogin: supportChat.enableLogin,
              onLogin: supportChat.onLogin,
              loginLabel: supportChat.loginLabel,
              failureMessage: supportChat.failureMessage,
              onExit: supportChat.onExit,
              onMessagesRead: supportChat.onMessagesRead,
            ),
      kycRoute,
      settings == null
          ? const []
          : List.unmodifiable(ExchangeSettingsRouter.routes(settings)),
      funding == null
          ? const []
          : List.unmodifiable(FundExchangeRouter.routes(funding)),
      autoBuy == null ? null : autoBuyRoute(autoBuy),
      auth == null
          ? null
          : exchangeAuthRoute(
              host: auth,
              networkUnavailable: networkUnavailable,
              showWebsiteOnly: showWebsiteOnly,
              homePath: unavailableRedirectPath,
              onExit: onExit,
            ),
      dashboard == null
          ? null
          : exchangeDashboardRoute(
              host: dashboard,
              kycRoute: kycRoute,
              networkUnavailable: networkUnavailable,
              showWebsiteOnly: showWebsiteOnly,
              homePath: unavailableRedirectPath,
              brandAsset: brandAssetPath,
              onExit: onExit,
              limitOrders: limitOrders,
            ),
      withdrawal == null ? null : withdrawRoute(withdrawal, brandAssetPath),
      limitOrders == null ? null : limitOrderDetailsRoute(limitOrders),
      purchases == null ? null : limitOrderCreationRoute(purchases),
      purchases == null ? const [] : List.unmodifiable(mountBuy(purchases)),
      purchases == null ? null : mountDca(purchases),
      payins == null ? null : mountSell(payins),
      payins == null ? null : mountPay(payins),
    );
  }
}
