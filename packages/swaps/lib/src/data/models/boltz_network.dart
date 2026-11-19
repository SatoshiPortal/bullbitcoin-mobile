import 'package:primitives/primitives.dart';
import 'package:rust_bindings/boltz.dart' as native;

enum BoltzNetwork {
  mainnet,
  testnet,
  regtest;

  String get value => name;

  factory BoltzNetwork.fromEnvironment(NetworkEnv environment) =>
      switch (environment) {
        NetworkEnv.mainnet => BoltzNetwork.mainnet,
        NetworkEnv.testnet => BoltzNetwork.testnet,
        NetworkEnv.regtest => BoltzNetwork.regtest,
        NetworkEnv.signet => throw ArgumentError('Unsupported swap network'),
      };

  NetworkEnv get environment => switch (this) {
    mainnet => NetworkEnv.mainnet,
    testnet => NetworkEnv.testnet,
    regtest => NetworkEnv.regtest,
  };

  native.Network get nativeNetwork => switch (this) {
    mainnet => native.Network.mainnet,
    testnet => native.Network.testnet,
    regtest => native.Network.regtest,
  };

  native.Chain nativeChain({required bool isLiquid}) =>
      switch ((this, isLiquid)) {
        (mainnet, false) => native.Chain.bitcoin,
        (mainnet, true) => native.Chain.liquid,
        (testnet, false) => native.Chain.bitcoinTestnet,
        (testnet, true) => native.Chain.liquidTestnet,
        (regtest, false) => native.Chain.bitcoinRegtest,
        (regtest, true) => native.Chain.liquidRegtest,
      };
}
