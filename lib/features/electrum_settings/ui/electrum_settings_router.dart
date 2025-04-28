import 'package:bb_mobile/features/electrum_settings/ui/widgets/electrum_server_settings.dart';
import 'package:flutter/material.dart';

/// Router for the Electrum Settings feature
class ElectrumSettingsRouter {
  /// Shows the Electrum Server Settings bottom sheet
  static void showElectrumServerSettings(BuildContext context) {
    ElectrumServerSettingsBottomSheet.showBottomSheet(context);
  }
}
