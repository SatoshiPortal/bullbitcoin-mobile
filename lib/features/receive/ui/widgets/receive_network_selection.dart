import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/features/receive/domain/enums/receive_network_type.dart';
import 'package:bb_mobile/features/receive/domain/extensions/wallet_receive_extensions.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReceiveNetworkSelection extends StatelessWidget {
  const ReceiveNetworkSelection({super.key, this.wallet});

  final Wallet? wallet;

  @override
  Widget build(BuildContext context) {
    final availableNetworks =
        wallet?.availableReceiveNetworks ?? ReceiveNetworkType.values;
    final defaultNetwork =
        wallet?.defaultReceiveNetwork ?? ReceiveNetworkType.bitcoin;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BBSegmentFull(
        items: {for (final type in availableNetworks) _label(context, type)},
        initialValue: _label(context, defaultNetwork),
        onSelected: (label) {
          final type = availableNetworks.firstWhere(
            (t) => _label(context, t) == label,
          );
          context.goNamed(_route(type).name, extra: wallet);
        },
      ),
    );
  }

  static ReceiveRoute _route(ReceiveNetworkType type) {
    return switch (type) {
      ReceiveNetworkType.bitcoin => ReceiveRoute.receiveBitcoin,
      ReceiveNetworkType.lightning => ReceiveRoute.receiveLightning,
      ReceiveNetworkType.liquid => ReceiveRoute.receiveLiquid,
    };
  }

  String _label(BuildContext context, ReceiveNetworkType type) {
    return switch (type) {
      ReceiveNetworkType.bitcoin => context.loc.receiveBitcoin,
      ReceiveNetworkType.lightning => context.loc.receiveLightning,
      ReceiveNetworkType.liquid => context.loc.receiveLiquid,
    };
  }
}
