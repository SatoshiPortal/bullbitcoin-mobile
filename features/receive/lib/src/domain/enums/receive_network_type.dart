import 'package:primitives/primitives.dart';

enum ReceiveNetworkType {
  bitcoin,
  lightning,
  liquid;

  /// Project a mode onto the concrete selected network's environment.
  bool supportsNetwork(Network network) {
    if (!NetworkCapabilities.supports(
      network,
      NetworkCapability.softwareWallet,
    )) {
      return false;
    }
    final bitcoinNetwork = BitcoinNetwork.values
        .where((n) => n.env == network.env)
        .firstOrNull;
    final liquidNetwork = LiquidNetwork.values
        .where((n) => n.env == network.env)
        .firstOrNull;
    return switch (this) {
      bitcoin =>
        bitcoinNetwork != null &&
            NetworkCapabilities.supports(
              bitcoinNetwork,
              NetworkCapability.softwareWallet,
            ),
      lightning =>
        NetworkCapabilities.supports(network, NetworkCapability.swaps) &&
            liquidNetwork != null &&
            NetworkCapabilities.supports(
              liquidNetwork,
              NetworkCapability.swaps,
            ),
      liquid =>
        liquidNetwork != null &&
            NetworkCapabilities.supports(
              liquidNetwork,
              NetworkCapability.softwareWallet,
            ),
    };
  }
}
