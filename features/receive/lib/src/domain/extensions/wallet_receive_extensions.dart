import 'package:receive/src/domain/receive_wallet.dart';
import 'package:receive/receive.dart';

extension WalletReceiveExtension on ReceiveWallet {
  List<ReceiveNetworkType> get availableReceiveNetworks {
    final candidates = _receiveNetworks;
    return candidates.where((type) => type.supportsNetwork(network)).toList();
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
      return signsLocally &&
              ReceiveNetworkType.lightning.supportsNetwork(network)
          ? ReceiveNetworkType.lightning
          : ReceiveNetworkType.liquid;
    }
    return ReceiveNetworkType.bitcoin;
  }
}
