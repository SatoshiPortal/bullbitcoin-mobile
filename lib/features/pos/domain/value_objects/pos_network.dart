import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:nostr_pos/nostr_pos.dart' as nostr;

enum PosNetwork {
  mainnet,
  testnet;

  bool get isTestnet => this == PosNetwork.testnet;

  nostr.PosNetwork get sdkNetwork {
    return switch (this) {
      PosNetwork.mainnet => nostr.PosNetwork.mainnet,
      PosNetwork.testnet => nostr.PosNetwork.testnet,
    };
  }

  Network get liquidWalletNetwork {
    return switch (this) {
      PosNetwork.mainnet => Network.liquidMainnet,
      PosNetwork.testnet => Network.liquidTestnet,
    };
  }

  factory PosNetwork.fromWalletNetwork(Network network) {
    if (!network.isLiquid) {
      throw ArgumentError('POS requires a Liquid wallet.');
    }
    return network.isTestnet ? PosNetwork.testnet : PosNetwork.mainnet;
  }

  factory PosNetwork.fromName(String value) {
    return PosNetwork.values.firstWhere((network) => network.name == value);
  }
}
