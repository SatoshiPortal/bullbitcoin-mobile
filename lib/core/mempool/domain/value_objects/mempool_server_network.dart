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

  String get networkString {
    switch (this) {
      case MempoolServerNetwork.bitcoinMainnet:
        return 'bitcoinMainnet';
      case MempoolServerNetwork.bitcoinTestnet:
        return 'bitcoinTestnet';
      case MempoolServerNetwork.liquidMainnet:
        return 'liquidMainnet';
      case MempoolServerNetwork.liquidTestnet:
        return 'liquidTestnet';
    }
  }

  static MempoolServerNetwork fromString(String network) {
    switch (network) {
      case 'bitcoinMainnet':
        return MempoolServerNetwork.bitcoinMainnet;
      case 'bitcoinTestnet':
        return MempoolServerNetwork.bitcoinTestnet;
      case 'liquidMainnet':
        return MempoolServerNetwork.liquidMainnet;
      case 'liquidTestnet':
        return MempoolServerNetwork.liquidTestnet;
      default:
        throw ArgumentError('Invalid network string: $network');
    }
  }
}
