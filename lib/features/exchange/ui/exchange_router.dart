import 'package:bb_mobile/features/dca/public/dca_facade.dart' show DcaRoute;
import 'package:bb_mobile/features/withdraw/public/withdraw_facade.dart'
    show WithdrawRoute;
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart'
    show TransactionsRoute;
import 'package:bull_ui/bull_ui.dart' show BullTypographyX;
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/exchange/ui/default_wallets_payout_binding.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/address_viewer.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';

import 'dart:async';

import 'dart:io';

import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:exchange/exchange.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    return [?feature.dashboardRoute, ...feature.routes];
  }

  static BullExchangeFeature mount(
    ExchangeRouterConfig config, {
    Exchange Function()? exchange,
    Preferences Function()? preferences,
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
    auth: ExchangeScope.authHost,
    dashboard: (
      exchange: exchange ?? ExchangeScope.exchange,
      preferences: preferences ?? ExchangeScope.preferences,
      currentAccess: ExchangeScope.currentAccess,
      watchAccess: ExchangeScope.accessChanges,
      watchDashboard: ExchangeScope.watchDashboard,
      refreshAccount: ExchangeScope.refreshSession,
      stopDca: ExchangeScope.stopDca,
      buildHomeCards: config.buildHomeCards,
      onHomeRefresh: config.onHomeRefresh,
      onOpenSettings: config.onOpenSettings,
      onOpenDca: (context) => context.pushNamed(DcaRoute.dca.name),
      onWithdraw: (context) => context.pushNamed(WithdrawRoute.withdraw.name),
      onHistory: (context) =>
          context.pushNamed(TransactionsRoute.transactions.name),
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
            terms: Uri.parse(SettingsConstants.exchangeTermsAndConditionsLink),
            addressViewer: (context, address) => AddressViewer(
              address,
              style: context.bullType.body,
              color: context.appColors.onSurface,
            ),
          ),
    funding: exchange == null
        ? null
        : (
            exchange: exchange,
            isLoggedIn: (context) =>
                !context.read<ExchangeCubit>().state.notLoggedIn,
          ),
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
}
