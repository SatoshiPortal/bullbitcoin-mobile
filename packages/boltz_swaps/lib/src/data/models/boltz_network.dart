enum BoltzNetwork {
  mainnet,
  testnet;

  String get value {
    switch (this) {
      case BoltzNetwork.mainnet:
        return 'mainnet';
      case BoltzNetwork.testnet:
        return 'testnet';
    }
  }
}
