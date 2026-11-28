import 'package:primitives/primitives.dart';

/// Restricts the experimental passkey integration to explicitly configured
/// Android debug builds and an approved network.
bool passkeysAvailableForBuild({
  required bool debug,
  required bool android,
  required bool web,
  required String rpId,
  required BitcoinNetwork? network,
  required bool mainnetOptIn,
}) {
  if (!debug || !android || web || rpId.isEmpty) return false;
  return network == BitcoinNetwork.regtest ||
      (network == BitcoinNetwork.mainnet && mainnetOptIn);
}
