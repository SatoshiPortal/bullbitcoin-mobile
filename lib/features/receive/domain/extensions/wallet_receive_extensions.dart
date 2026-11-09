import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/receive/domain/enums/receive_network_type.dart';

extension WalletReceiveExtension on Wallet {
  List<ReceiveNetworkType> get availableReceiveNetworks {
    final candidates = _receiveNetworks;
    return candidates
        .where((type) => type.supportsNetwork(network.shared))
        .toList();
  }

  List<ReceiveNetworkType> get _receiveNetworks {
    if (isLiquid) {
      return signsLocally
          ? [ReceiveNetworkType.lightning, ReceiveNetworkType.liquid]
          : [ReceiveNetworkType.liquid];
    }
    return signsLocally
        ? [ReceiveNetworkType.bitcoin, ReceiveNetworkType.lightning]
        : [ReceiveNetworkType.bitcoin];
  }

  ReceiveNetworkType get defaultReceiveNetwork {
    if (isLiquid) {
      return signsLocally
          ? ReceiveNetworkType.lightning
          : ReceiveNetworkType.liquid;
    }
    return ReceiveNetworkType.bitcoin;
  }
}
