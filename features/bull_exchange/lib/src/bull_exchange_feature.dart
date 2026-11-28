import 'dart:async';

import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_ui/bull_ui.dart' show BullTypographyX;
import 'package:exchange/exchange.dart';
import 'package:fees/fees.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show WalletInventory;
import 'package:sync/write.dart' show WalletNativeLifecycle;
import 'package:transactions/routes.dart';
import 'package:transactions/transactions.dart';

import 'autobuy/autobuy_mount.dart';
import 'dashboard/exchange_dashboard_route.dart';
import 'dashboard/exchange_home_actions.dart';
import 'dca/ui/dca_router.dart';
import 'exchange_failure_l10n.dart';
import 'exchange_l10n.dart';
import 'exchange_payout_destinations.dart';
import 'session/exchange_access_builder.dart';
import 'session/exchange_session_scope.dart';
import 'auth/exchange_auth_route.dart';
import 'auth/exchange_auth_host.dart';
import 'auth/exchange_auth_screen.dart';
import 'exchange_landing_copy.dart';
import 'exchange_landing_navigation.dart';
import 'buy/mount_buy.dart';
import 'dca/mount_dca.dart';
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

/// Wallet services and app navigation for Buy, DCA and limit orders.
typedef ExchangePurchaseServices = ({
  AmountDisplayPreferencesReader Function() displayPreferences,
  WalletInventory Function() inventory,
  WalletNativeLifecycle Function() native,
  Fees Function() fees,
  PayjoinSessions Function() payjoinSessions,
  PayjoinReceiver Function() payjoinReceiver,
  PayjoinPolicyAccess Function() payjoinPolicy,
  Future<void> Function(String walletId) pollWallet,
  Transactions Function() transactions,
  String bitcoinAsset,
  void Function(BuildContext) onClose,
});

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
  final GoRoute? sellRoute;
  final GoRoute? payRoute;

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

  /// Mounts every Exchange journey over the opened [exchange] capability.
  /// The host supplies app navigation, branding, the settings slot and the
  /// wallet services that Buy, DCA, Sell and Pay need.
  static BullExchangeFeature mount({
    required Exchange Function() exchange,
    required Preferences Function() preferences,
    required bool Function(BuildContext) isSuperuser,
    required String homePath,
    required void Function(BuildContext) onExit,
    required void Function(BuildContext) onOpenSettings,
    required void Function(BuildContext, ExchangeHomeAction) onAction,
    required String brandAssetPath,
    required String settingsAssetPath,
    ExchangeSettingsHost? settings,
    ExchangePurchaseServices? purchases,
    ExchangePayinHost? payins,
  }) {
    String failureMessage(BuildContext context, ExchangeFailure failure) =>
        failure.toTranslated(context);
    bool isLoggedIn(BuildContext _) =>
        exchangeSignedIn(exchange().currentAccess);
    return mountBullExchange(
      networkUnavailable: () => exchange().networkUnavailable(),
      showWebsiteOnly: (context) => ExchangePlatform.current.websiteOnly(
        isSuperuser: isSuperuser(context),
      ),
      unavailableRedirectPath: homePath,
      brandAssetPath: brandAssetPath,
      onExit: onExit,
      settingsRoutes: settings == null
          ? const []
          : ExchangeSettingsRouter.routes(
              settings,
              exchange: exchange,
              preferences: preferences,
              homePath: homePath,
              onExit: onExit,
              payoutFields: exchangePayoutFields,
            ),
      purchases: purchases == null
          ? null
          : (
              exchange: exchange,
              preferences: preferences,
              displayPreferences: purchases.displayPreferences,
              inventory: purchases.inventory,
              native: purchases.native,
              fees: purchases.fees,
              payjoinSessions: purchases.payjoinSessions,
              payjoinReceiver: purchases.payjoinReceiver,
              payjoinPolicy: purchases.payjoinPolicy,
              pollWallet: purchases.pollWallet,
              labelOrders: (orders) =>
                  purchases.transactions().labelCompletedExchangeOrders(orders),
              validateBitcoinAddress: validateExchangeBitcoinAddress,
              payoutField: exchangePurchasePayoutField,
              bitcoinAsset: purchases.bitcoinAsset,
              onClose: purchases.onClose,
              openOrder: (context, id) => TransactionsNavigation.openDetails(
                context,
                TransactionDetailsTarget.order(id),
                view: TransactionDetailsView.details,
              ),
            ),
      payins: payins,
      auth: exchangeAuthHost(exchange),
      limitOrders: exchange,
      withdrawal: (
        exchange: exchange,
        preferences: preferences,
        openOrder: (context, orderId) => TransactionsNavigation.openDetails(
          context,
          TransactionDetailsTarget.order(orderId),
          returnToExchange: true,
        ),
      ),
      dashboard: (
        exchange: exchange,
        preferences: preferences,
        currentAccess: () => exchange().currentAccess,
        watchAccess: () => exchange().watchAccess(),
        watchDashboard: ExchangeSessionScope.watchDashboard,
        watchUnreadSupportMessages:
            ExchangeSessionScope.watchUnreadSupportMessages,
        refreshAccount: ExchangeSessionScope.refresh,
        stopDca: ExchangeSessionScope.stopDca,
        onOpenSettings: onOpenSettings,
        onOpenDca: (context) => context.pushNamed(DcaRoute.dca.name),
        onWithdraw: (context) => context.pushNamed(WithdrawRoute.withdraw.name),
        onHistory: TransactionsNavigation.openHistory,
        onAction: onAction,
        failureMessage: failureMessage,
        settingsAsset: settingsAssetPath,
      ),
      autoBuy: (
        exchange: exchange,
        preferences: preferences,
        payoutFields: exchangePayoutFields,
        terms: Uri.parse(ExchangeDefaults.exchangeTermsAndConditionsLink),
        addressViewer: (context, address) => AddressViewer(
          address,
          style: context.bullType.body,
          color: context.appColors.onSurface,
        ),
      ),
      funding: (exchange: exchange),
      kyc: ExchangeKycHost(
        loadConfiguration: () => exchange().loadKyc(),
        failureMessage: failureMessage,
        onExit: (context) {
          unawaited(ExchangeSessionScope.refresh(context));
          context.pop();
        },
      ),
      supportChat: (
        exchange: exchange,
        isLoggedIn: isLoggedIn,
        enableLogin: (_) => exchange().enableAccess(forSupport: true),
        onLogin: (context, draft) => context.goNamed(
          BullExchangeNavigation.authName,
          queryParameters: {'from': 'support'},
          extra: draft,
        ),
        loginLabel: (context) => context.loc.exchangeLoginButton,
        failureMessage: failureMessage,
        onMessagesRead: ExchangeSessionScope.markSupportMessagesRead,
        onExit: (context, fromExchange) {
          if (fromExchange) {
            BullExchangeNavigation.goToDashboard(context);
          } else {
            onExit(context);
          }
        },
      ),
    );
  }
}

/// Mounts the routes over already composed hosts. Internal to the member:
/// the application uses [BullExchangeFeature.mount].
@internal
BullExchangeFeature mountBullExchange({
  required Future<bool> Function() networkUnavailable,
  required bool Function(BuildContext) showWebsiteOnly,
  required String unavailableRedirectPath,
  required String brandAssetPath,
  required void Function(BuildContext) onExit,
  ExchangeSupportChatHost? supportChat,
  ExchangeKycHost? kyc,
  List<RouteBase> settingsRoutes = const [],
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
          path: BullExchangeNavigation.kycSegment,
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
    List.unmodifiable(settingsRoutes),
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
