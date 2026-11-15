import 'network.dart';

/// Permission on a concrete chain; consent and backend readiness still apply.
enum NetworkCapability {
  softwareWallet,
  exchange,
  swaps,
  payjoin,
  hardwareWallet,
  ark,
  silentPayments,
  publicExplorer,
  publicFeeEstimates,
}

/// Pure policy. A feature owns the failure it returns when permission is absent.
abstract final class NetworkCapabilities {
  static bool supports(Network network, NetworkCapability capability) =>
      switch (network) {
        BitcoinNetwork.mainnet ||
        BitcoinNetwork.testnet => switch (capability) {
          NetworkCapability.ark => false,
          NetworkCapability.softwareWallet ||
          NetworkCapability.exchange ||
          NetworkCapability.swaps ||
          NetworkCapability.payjoin ||
          NetworkCapability.hardwareWallet ||
          NetworkCapability.silentPayments ||
          NetworkCapability.publicExplorer ||
          NetworkCapability.publicFeeEstimates => true,
        },
        LiquidNetwork.mainnet || LiquidNetwork.testnet => switch (capability) {
          NetworkCapability.payjoin ||
          NetworkCapability.ark ||
          NetworkCapability.silentPayments => false,
          NetworkCapability.softwareWallet ||
          NetworkCapability.exchange ||
          NetworkCapability.swaps ||
          NetworkCapability.hardwareWallet ||
          NetworkCapability.publicExplorer ||
          NetworkCapability.publicFeeEstimates => true,
        },
        BitcoinNetwork.regtest => switch (capability) {
          NetworkCapability.softwareWallet => true,
          NetworkCapability.exchange ||
          NetworkCapability.swaps ||
          NetworkCapability.payjoin ||
          NetworkCapability.hardwareWallet ||
          NetworkCapability.ark ||
          NetworkCapability.silentPayments ||
          NetworkCapability.publicExplorer ||
          NetworkCapability.publicFeeEstimates => false,
        },
        LiquidNetwork.regtest => capability == NetworkCapability.softwareWallet,
        BitcoinNetwork.signet => false,
      };
}
