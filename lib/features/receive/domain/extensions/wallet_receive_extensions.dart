import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/receive/domain/enums/receive_network_type.dart';

extension WalletReceiveExtension on Wallet {
  List<ReceiveNetworkType> get availableReceiveNetworks {
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
