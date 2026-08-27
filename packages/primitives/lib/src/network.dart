/// The network environment, orthogonal to the chain.
enum NetworkEnv { mainnet, testnet, signet, regtest }

/// A Bitcoin network. The chain is the type; [env] is the environment.
enum BitcoinNetwork {
  mainnet(NetworkEnv.mainnet),
  testnet(NetworkEnv.testnet),
  signet(NetworkEnv.signet),
  regtest(NetworkEnv.regtest);

  final NetworkEnv env;

  const BitcoinNetwork(this.env);

  bool get isMainnet => env == NetworkEnv.mainnet;

  /// BIP44 coin type: 0 on mainnet, 1 for every test environment.
  int get coinType => isMainnet ? 0 : 1;

  factory BitcoinNetwork.fromName(String name) => values.firstWhere(
    (network) => network.name == name,
    orElse: () =>
        throw ArgumentError.value(name, 'name', 'unknown BitcoinNetwork'),
  );

  /// Non-throwing parse for untrusted or persisted input.
  static BitcoinNetwork? tryFromName(String name) {
    for (final network in values) {
      if (network.name == name) return network;
    }
    return null;
  }
}

/// A Liquid network. Liquid has no signet, so there is no such value.
enum LiquidNetwork {
  mainnet(NetworkEnv.mainnet),
  testnet(NetworkEnv.testnet),
  regtest(NetworkEnv.regtest);

  final NetworkEnv env;

  const LiquidNetwork(this.env);

  bool get isMainnet => env == NetworkEnv.mainnet;

  /// SLIP-44 coin type: 1776 on mainnet, 1 for test environments.
  int get coinType => isMainnet ? 1776 : 1;

  factory LiquidNetwork.fromName(String name) => values.firstWhere(
    (network) => network.name == name,
    orElse: () =>
        throw ArgumentError.value(name, 'name', 'unknown LiquidNetwork'),
  );

  /// Non-throwing parse for untrusted or persisted input.
  static LiquidNetwork? tryFromName(String name) {
    for (final network in values) {
      if (network.name == name) return network;
    }
    return null;
  }
}
