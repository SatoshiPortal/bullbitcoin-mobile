import 'package:primitives/primitives.dart';

bool swapEnvironmentAvailable(NetworkEnv environment) =>
    NetworkCapabilities.supports(switch (environment) {
      NetworkEnv.mainnet => BitcoinNetwork.mainnet,
      NetworkEnv.testnet => BitcoinNetwork.testnet,
      NetworkEnv.regtest => BitcoinNetwork.regtest,
      NetworkEnv.signet => BitcoinNetwork.signet,
    }, NetworkCapability.swaps);
