import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'electrum_settings/ui/electrum_settings_router.dart';
import 'mempool_settings/router.dart';
import 'tor_settings/ui/tor_settings_router.dart';

const serviceStatusRouteName = 'serviceStatus';

enum NetworkSection { electrum, mempool, tor, status }

abstract final class NetworkNavigation {
  static Future<void> open(
    BuildContext context, {
    required NetworkSection section,
  }) => context.pushNamed<void>(switch (section) {
    NetworkSection.electrum => ElectrumSettingsRoute.electrumSettings.name,
    NetworkSection.mempool => MempoolSettingsRoute.name,
    NetworkSection.tor => TorSettingsRoute.torSettings.name,
    NetworkSection.status => serviceStatusRouteName,
  });
}
