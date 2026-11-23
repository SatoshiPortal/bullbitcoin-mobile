import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../default_wallets_payout_fields.dart';
import 'screens/default_wallets_screen.dart';

abstract final class DefaultWalletsNavigation {
  static const name = 'defaultWallets';
  static const path = 'exchange-bitcoin-wallets';

  static Future<void> open(BuildContext context) =>
      context.pushNamed<void>(name);
}

typedef DefaultWalletsHost = ({
  Future<bool> Function() isAvailable,
  String unavailableRedirectPath,
});

GoRoute defaultWalletsRoute(
  Exchange Function() exchange,
  DefaultWalletsHost host,
  DefaultWalletsPayoutFields payoutFields,
) => GoRoute(
  name: DefaultWalletsNavigation.name,
  path: DefaultWalletsNavigation.path,
  redirect: (_, _) async =>
      await host.isAvailable() ? null : host.unavailableRedirectPath,
  builder: (_, _) => DefaultWalletsScreen(
    exchange: exchange(),
    payoutFields: payoutFields,
  ),
);
