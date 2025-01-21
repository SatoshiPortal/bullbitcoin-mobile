import 'package:bb_mobile/features/pin_code/presentation/flows/pin_code_setting_flow.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum SettingsRoute {
  pinCode('/pinCode'),
  fiatCurrency('/fiatCurrency');

  final String path;

  const SettingsRoute(this.path);
}

class SettingsRoutes {
  static final routes = [
    GoRoute(
      name: SettingsRoute.pinCode.name,
      path: SettingsRoute.pinCode.path,
      builder: (context, state) => const PinCodeSettingFlow(),
    ),
    GoRoute(
      name: SettingsRoute.fiatCurrency.name,
      path: SettingsRoute.fiatCurrency.path,
      builder: (context, state) => const Text('Fiat currency selector'),
    ),
  ];
}
