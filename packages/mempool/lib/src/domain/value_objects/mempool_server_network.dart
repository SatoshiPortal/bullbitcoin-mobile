import 'package:primitives/primitives.dart';

enum MempoolServerNetwork {
  bitcoinMainnet,
  bitcoinTestnet,
  liquidMainnet,
  liquidTestnet;

  factory MempoolServerNetwork.fromEnvironment({
    required bool isTestnet,
    required bool isLiquid,
  }) {
    if (isLiquid && isTestnet) return MempoolServerNetwork.liquidTestnet;
    if (isLiquid && !isTestnet) return MempoolServerNetwork.liquidMainnet;
    if (!isLiquid && isTestnet) return MempoolServerNetwork.bitcoinTestnet;
    return MempoolServerNetwork.bitcoinMainnet;
  }

  bool get isTestnet {
    return this == MempoolServerNetwork.bitcoinTestnet ||
        this == MempoolServerNetwork.liquidTestnet;
  }

  bool get isLiquid {
    return this == MempoolServerNetwork.liquidMainnet ||
        this == MempoolServerNetwork.liquidTestnet;
  }

  Network get network => switch (this) {
    bitcoinMainnet => BitcoinNetwork.mainnet,
    bitcoinTestnet => BitcoinNetwork.testnet,
    liquidMainnet => LiquidNetwork.mainnet,
    liquidTestnet => LiquidNetwork.testnet,
  };

  static MempoolServerNetwork? fromNetwork(Network network) =>
      switch (network) {
        BitcoinNetwork.mainnet => bitcoinMainnet,
        BitcoinNetwork.testnet => bitcoinTestnet,
        LiquidNetwork.mainnet => liquidMainnet,
        LiquidNetwork.testnet => liquidTestnet,
        BitcoinNetwork.regtest ||
        BitcoinNetwork.signet ||
        LiquidNetwork.regtest => null,
      };
}
