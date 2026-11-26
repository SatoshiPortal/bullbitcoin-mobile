import 'package:primitives/primitives.dart';

extension SwapNetworkEnv on NetworkEnv {
  bool requireSwapTestnet() => switch (this) {
    NetworkEnv.mainnet => false,
    NetworkEnv.testnet => true,
    _ => throw const UnsupportedNetworkException(),
  };
}
