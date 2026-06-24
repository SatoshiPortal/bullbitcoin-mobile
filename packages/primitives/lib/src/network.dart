/// Bitcoin / Liquid network, modelled on the two orthogonal axes a network
/// actually has: the **chain** (the enum type — [BitcoinNetwork] / [LiquidNetwork])
/// and the **environment** ([NetworkEnv]). This replaces the former flat enum
/// whose four mutually-exclusive booleans (`isBitcoin`/`isLiquid`/`isMainnet`/
/// `isTestnet`) both permitted invalid states and could not express signet /
/// regtest without a combinatorial blow-up.
///
/// Per-chain APIs take the chain type directly, so a wrong-chain value is a
/// compile error rather than a runtime check.
library;

/// The network environment — orthogonal to the chain.
enum NetworkEnv { mainnet, testnet, signet, regtest }

/// A Bitcoin network. The chain is the type; [env] is the environment.
enum BitcoinNetwork {
  mainnet(NetworkEnv.mainnet),
  testnet(NetworkEnv.testnet),
  signet(NetworkEnv.signet),
  regtest(NetworkEnv.regtest);

  const BitcoinNetwork(this.env);

  final NetworkEnv env;

  bool get isMainnet => env == NetworkEnv.mainnet;

  /// BIP44 coin type: 0 on mainnet, 1 for every test environment
  /// (testnet/signet/regtest all share coin type 1, per SLIP-44).
  int get coinType => isMainnet ? 0 : 1;

  factory BitcoinNetwork.fromName(String name) => values.firstWhere(
        (n) => n.name == name,
        orElse: () =>
            throw ArgumentError.value(name, 'name', 'unknown BitcoinNetwork'),
      );

  /// Non-throwing parse for untrusted/persisted input.
  static BitcoinNetwork? tryFromName(String name) {
    for (final n in values) {
      if (n.name == name) return n;
    }
    return null;
  }
}

/// A Liquid network. Liquid has no signet, so there is simply no such value.
enum LiquidNetwork {
  mainnet(NetworkEnv.mainnet),
  testnet(NetworkEnv.testnet),
  regtest(NetworkEnv.regtest);

  const LiquidNetwork(this.env);

  final NetworkEnv env;

  bool get isMainnet => env == NetworkEnv.mainnet;

  /// SLIP-44 coin type: 1776 on Liquid mainnet, 1 for test environments.
  int get coinType => isMainnet ? 1776 : 1;

  factory LiquidNetwork.fromName(String name) => values.firstWhere(
        (n) => n.name == name,
        orElse: () =>
            throw ArgumentError.value(name, 'name', 'unknown LiquidNetwork'),
      );

  /// Non-throwing parse for untrusted/persisted input.
  static LiquidNetwork? tryFromName(String name) {
    for (final n in values) {
      if (n.name == name) return n;
    }
    return null;
  }
}
