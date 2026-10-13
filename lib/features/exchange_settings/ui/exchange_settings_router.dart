import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange_settings/public/exchange_settings_facade.dart';
import 'package:bb_mobile/features/exchange_settings/ui/screens/exchange_settings_screen.dart';
import 'package:bb_mobile/features/exchange_settings/ui/screens/referrals_screen.dart';
import 'package:bb_mobile/features/exchange_settings/ui/screens/security_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

enum ExchangeSettingsRoute {
  home('exchange-settings'),
  security('exchange-security'),
  referrals('exchange-referrals'),
  accountInfo('exchange-account-info'),
  preferences('exchange-app-settings'),
  secureFileUpload('secure-file-upload'),
  statistics('exchange-statistics');

  final String path;

  const ExchangeSettingsRoute(this.path);
}

class ExchangeSettingsRouterConfig {
  final bool Function(BuildContext) isSuperuser;
  final bool Function(BuildContext) isTestnet;
  final void Function(BuildContext) onOpenRecipients;
  final void Function(BuildContext) onOpenTransactions;
  final void Function(BuildContext) onOpenDefaultWallets;

  const ExchangeSettingsRouterConfig({
    required this.isSuperuser,
    required this.isTestnet,
    required this.onOpenRecipients,
    required this.onOpenTransactions,
    required this.onOpenDefaultWallets,
  });
}

class ExchangeSettingsRouter {
  static List<RouteBase> routes(ExchangeSettingsRouterConfig config) => [
    GoRoute(
      name: ExchangeSettingsRoute.home.name,
      path: ExchangeSettingsRoute.home.path,
      builder: (context, state) => ExchangeSessionListener(
        listenWhen: (wasLoggedIn, isLoggedIn) => wasLoggedIn && !isLoggedIn,
        listener: (context, _) =>
            context.goNamed(ExchangeRoute.exchangeLanding.name),
        child: ExchangeSettingsScreen(
          isSuperuser: config.isSuperuser(context),
          onOpenRecipients: () => config.onOpenRecipients(context),
          onOpenTransactions: () => config.onOpenTransactions(context),
          onOpenDefaultWallets: () => config.onOpenDefaultWallets(context),
        ),
      ),
    ),
    GoRoute(
      name: ExchangeSettingsRoute.security.name,
      path: ExchangeSettingsRoute.security.path,
      builder: (context, state) =>
          ExchangeSecurityScreen(isTestnet: config.isTestnet(context)),
    ),
    GoRoute(
      name: ExchangeSettingsRoute.referrals.name,
      path: ExchangeSettingsRoute.referrals.path,
      builder: (context, state) => const ExchangeReferralsScreen(),
    ),
    GoRoute(
      name: ExchangeSettingsRoute.accountInfo.name,
      path: ExchangeSettingsRoute.accountInfo.path,
      builder: (context, state) =>
          locator<ExchangeSettingsFacade>().buildAccountInfoScreen(),
    ),
    GoRoute(
      name: ExchangeSettingsRoute.preferences.name,
      path: ExchangeSettingsRoute.preferences.path,
      builder: (context, state) =>
          locator<ExchangeSettingsFacade>().buildPreferencesScreen(),
    ),
    GoRoute(
      name: ExchangeSettingsRoute.secureFileUpload.name,
      path: ExchangeSettingsRoute.secureFileUpload.path,
      builder: (context, state) =>
          locator<ExchangeSettingsFacade>().buildSecureFileUploadScreen(),
    ),
    GoRoute(
      name: ExchangeSettingsRoute.statistics.name,
      path: ExchangeSettingsRoute.statistics.path,
      builder: (context, state) =>
          locator<ExchangeSettingsFacade>().buildStatisticsScreen(),
    ),
  ];
}
