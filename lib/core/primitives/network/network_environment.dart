enum BitcoinNetworkEnvironment { mainnet, testnet3 }

enum LiquidNetworkEnvironment { mainnet, testnet }

//enum ArkadeNetworkEnvironment { mainnet, testnet }

extension BitcoinNetworkEnvironmentExtension on BitcoinNetworkEnvironment {
  bool get isMainnet => this == BitcoinNetworkEnvironment.mainnet;
  bool get isTestnet => this == BitcoinNetworkEnvironment.testnet3;
}

extension LiquidNetworkEnvironmentExtension on LiquidNetworkEnvironment {
  bool get isMainnet => this == LiquidNetworkEnvironment.mainnet;
  bool get isTestnet => this == LiquidNetworkEnvironment.testnet;
}
