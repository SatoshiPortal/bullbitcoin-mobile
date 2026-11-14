import 'package:primitives/primitives.dart' as primitives;
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/receive/domain/enums/receive_network_type.dart';
import 'package:bb_mobile/features/receive/domain/extensions/wallet_receive_extensions.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart' show BullSegmented;

class ReceiveNetworkSelection extends StatelessWidget {
  const ReceiveNetworkSelection({super.key, this.wallet, this.network});

  final Wallet? wallet;
  final primitives.Network? network;

  @override
  Widget build(BuildContext context) {
    final activeNetwork = network;
    final availableNetworks =
        wallet?.availableReceiveNetworks ??
        [
          if (activeNetwork != null)
            for (final type in ReceiveNetworkType.values)
              if (type.supportsNetwork(activeNetwork)) type,
        ];
    if (availableNetworks.isEmpty) return const SizedBox.shrink();
    final defaultNetwork =
        wallet?.defaultReceiveNetwork ?? ReceiveNetworkType.bitcoin;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BullSegmented(
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
