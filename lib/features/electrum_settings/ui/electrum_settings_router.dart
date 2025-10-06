import 'package:bb_mobile/features/electrum_settings/ui/screens/electrum_settings_screen.dart';
import 'package:flutter/material.dart';

/// Router for the Electrum Settings feature
class ElectrumSettingsRouter {
  /// Shows the Electrum Server Settings screen
  static void showElectrumServerSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ElectrumSettingsScreen()),
    );
  }
}
