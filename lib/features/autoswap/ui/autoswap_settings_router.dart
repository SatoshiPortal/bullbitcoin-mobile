import 'package:bb_mobile/features/autoswap/ui/widgets/autoswap_settings.dart';
import 'package:flutter/material.dart';

/// Router for the Auto Swap Settings feature
class AutoSwapSettingsRouter {
  /// Shows the Auto Swap Settings bottom sheet
  static void showAutoSwapSettings(BuildContext context) {
    AutoSwapSettingsBottomSheet.showBottomSheet(context);
  }
}
