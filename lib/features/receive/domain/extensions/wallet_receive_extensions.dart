import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/receive/domain/enums/receive_network_type.dart';

extension WalletReceiveExtension on Wallet? {
  Set<ReceiveNetworkType> get availableReceiveNetworks {
    if (this == null) {
      return {
        ReceiveNetworkType.bitcoin,
        ReceiveNetworkType.lightning,
        ReceiveNetworkType.liquid,
      };
    }

    final wallet = this!;
    if (wallet.isLiquid) {
      if (wallet.signsLocally) {
        return {ReceiveNetworkType.lightning, ReceiveNetworkType.liquid};
      } else {
        return {ReceiveNetworkType.liquid};
      }
    } else {
      if (wallet.signsLocally) {
        return {ReceiveNetworkType.bitcoin, ReceiveNetworkType.lightning};
      } else {
        return {ReceiveNetworkType.bitcoin};
      }
    }
  }

  ReceiveNetworkType get defaultReceiveNetwork {
    if (this == null) return ReceiveNetworkType.bitcoin;

    final wallet = this!;
    if (wallet.isLiquid) {
      return wallet.signsLocally
          ? ReceiveNetworkType.lightning
          : ReceiveNetworkType.liquid;
    }

    return ReceiveNetworkType.bitcoin;
  }
}
