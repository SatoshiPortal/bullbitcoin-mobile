enum ElectrumEnvironment { mainnet, testnet }

extension ElectrumEnvironmentX on ElectrumEnvironment {
  bool get isTestnet => this == ElectrumEnvironment.testnet;
  bool get isMainnet => this == ElectrumEnvironment.mainnet;
}
