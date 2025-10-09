enum ElectrumServerNetwork {
  bitcoinMainnet,
  bitcoinTestnet,
  liquidMainnet,
  liquidTestnet;

  static ElectrumServerNetwork fromEnvironment({
    required bool isTestnet,
    required bool isLiquid,
  }) {
    if (isLiquid) {
      return isTestnet
          ? ElectrumServerNetwork.liquidTestnet
          : ElectrumServerNetwork.liquidMainnet;
    } else {
      return isTestnet
          ? ElectrumServerNetwork.bitcoinTestnet
          : ElectrumServerNetwork.bitcoinMainnet;
    }
  }
}

extension ElectrumServerNetworkX on ElectrumServerNetwork {
  bool get isTestnet =>
      this == ElectrumServerNetwork.bitcoinTestnet ||
      this == ElectrumServerNetwork.liquidTestnet;

  bool get isLiquid =>
      this == ElectrumServerNetwork.liquidMainnet ||
      this == ElectrumServerNetwork.liquidTestnet;
}
