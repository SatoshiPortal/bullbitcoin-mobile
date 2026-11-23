import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'src/domain/extensions/wallet_receive_extensions.dart';
import 'src/domain/enums/receive_network_type.dart';
import 'src/domain/receive_wallet.dart';
import 'src/ui/receive_router.dart';

abstract final class ReceiveNavigation {
  static Future<T?> open<T extends Object?>(
    BuildContext context, {
    ReceiveWallet? wallet,
  }) {
    final mode = wallet?.defaultReceiveNetwork ?? ReceiveNetworkType.bitcoin;
    final route = switch (mode) {
      ReceiveNetworkType.bitcoin => ReceiveRoute.receiveBitcoin,
      ReceiveNetworkType.lightning => ReceiveRoute.receiveLightning,
      ReceiveNetworkType.liquid => ReceiveRoute.receiveLiquid,
    };
    return context.pushNamed<T>(route.name, extra: wallet);
  }
}
