import 'package:primitives/primitives.dart' show NetworkEnv;

enum ElectrumEnvironment { mainnet, testnet, regtest }

extension ElectrumEnvironmentX on ElectrumEnvironment {
  NetworkEnv get networkEnv => switch (this) {
    ElectrumEnvironment.mainnet => NetworkEnv.mainnet,
    ElectrumEnvironment.testnet => NetworkEnv.testnet,
    ElectrumEnvironment.regtest => NetworkEnv.regtest,
  };

  bool get isMainnet => this == ElectrumEnvironment.mainnet;
}
