import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Router for the Auto Swap Settings feature
class AutoSwapSettingsRouter {
  /// Shows the Auto Swap Settings screen
  static void showAutoSwapSettings(BuildContext context) {
    context.pushNamed(SettingsRoute.autoswapSettings.name);
  }
}
