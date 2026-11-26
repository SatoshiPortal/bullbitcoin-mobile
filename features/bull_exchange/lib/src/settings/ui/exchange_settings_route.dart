import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navigation names for the Exchange destinations inside app settings.
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

  Future<void> open(BuildContext context) => context.pushNamed<void>(name);
}
