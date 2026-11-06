enum ElectrumEnvironment { mainnet, testnet, regtest }

extension ElectrumEnvironmentX on ElectrumEnvironment {
  bool get isMainnet => this == ElectrumEnvironment.mainnet;
}
