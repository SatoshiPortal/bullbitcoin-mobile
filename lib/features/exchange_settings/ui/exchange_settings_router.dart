import 'package:bb_mobile/features/exchange_settings/public/exchange_settings_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:go_router/go_router.dart';

enum ExchangeSettingsRoute {
  accountInfo('exchange-account-info'),
  preferences('exchange-app-settings'),
  secureFileUpload('secure-file-upload'),
  exchangeStatistics('exchange-statistics');

  final String path;

  const ExchangeSettingsRoute(this.path);
}

class ExchangeSettingsRouter {
  static final routes = [
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
      name: ExchangeSettingsRoute.exchangeStatistics.name,
      path: ExchangeSettingsRoute.exchangeStatistics.path,
      builder: (context, state) =>
          locator<ExchangeSettingsFacade>().buildStatisticsScreen(),
    ),
  ];
}
