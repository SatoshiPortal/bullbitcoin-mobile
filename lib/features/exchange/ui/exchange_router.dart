import 'package:transactions/routes.dart';
import 'package:bull_ui/bull_ui.dart' show BullTypographyX;
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/exchange/ui/default_wallets_payout_binding.dart';
import 'package:address_view/address_view.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_failure_l10n.dart';

import 'dart:async';

import 'dart:io';

import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart' show Result;
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

enum ExchangeRoute {
  exchangeHome(BullExchangeNavigation.dashboardPath),
  exchangeAuth(BullExchangeNavigation.authPath);

  final String path;

  const ExchangeRoute(this.path);
}

class ExchangeRouterConfig {
  final Future<bool> Function() networkUnavailable;
  final bool Function(BuildContext) isSuperuser;
  final String homePath;
  final void Function(BuildContext) onExit;
  final void Function(BuildContext) onOpenSettings;
  final void Function(BuildContext, ExchangeHomeAction) onAction;
  final Future<Result<ExchangeKycConfiguration, ExchangeFailure>> Function()?
  loadKyc;

  const ExchangeRouterConfig({
    required this.networkUnavailable,
    required this.isSuperuser,
    required this.homePath,
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
    return [?feature.dashboardRoute, ...feature.routes];
  }

  static BullExchangeFeature mount(
    ExchangeRouterConfig config, {
    Exchange Function()? exchange,
    Preferences Function()? preferences,
    ExchangeSettingsHost? settings,
    ExchangePurchaseHost? purchases,
    ExchangePayinHost? payins,
  }) => BullExchangeFeature.mount(
    networkUnavailable: config.networkUnavailable,
    showWebsiteOnly: (context) =>
        Platform.isIOS && !config.isSuperuser(context),
    unavailableRedirectPath: config.homePath,
    brandAssetPath: Assets.logos.bbLogoSmall.path,
    onExit: config.onExit,
    settings: settings,
    purchases: purchases,
    payins: payins,
    auth: ExchangeScope.authHost,
    limitOrders: exchange,
    withdrawal: exchange == null || preferences == null
        ? null
        : (
            exchange: exchange,
            preferences: preferences,
            isLoggedIn: ExchangeSessionScope.hasAccount,
            openOrder: (context, orderId) => TransactionsNavigation.openDetails(
              context,
              TransactionDetailsTarget.order(orderId),
              returnToExchange: true,
            ),
          ),
    dashboard: (
      exchange: exchange ?? ExchangeScope.exchange,
      preferences: preferences ?? ExchangeScope.preferences,
      currentAccess: ExchangeScope.currentAccess,
      watchAccess: ExchangeScope.accessChanges,
      watchDashboard: ExchangeSessionScope.watchDashboard,
      refreshAccount: ExchangeSessionScope.refresh,
      stopDca: ExchangeSessionScope.stopDca,
      onOpenSettings: config.onOpenSettings,
      onOpenDca: (context) => context.pushNamed(DcaRoute.dca.name),
      onWithdraw: (context) => context.pushNamed(WithdrawRoute.withdraw.name),
      onHistory: TransactionsNavigation.openHistory,
      onAction: config.onAction,
      failureMessage: (context, failure) => failure.toTranslated(context),
      settingsAsset: Assets.icons.settingsLine.path,
    ),
    autoBuy: exchange == null || preferences == null
        ? null
        : (
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
    funding: exchange == null
        ? null
        : (exchange: exchange, isLoggedIn: ExchangeSessionScope.hasAccount),
    kyc: switch (config.loadKyc) {
      final load? => ExchangeKycHost(
        loadConfiguration: load,
        failureMessage: (context, failure) => failure.toTranslated(context),
        onExit: (context) {
          unawaited(ExchangeSessionScope.refresh(context));
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
            enableLogin: (_) => exchange().enableAccess(forSupport: true),
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
}
