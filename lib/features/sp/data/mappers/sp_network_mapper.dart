import 'package:bull_sdk/bwk.dart' as bwk;
import 'package:primitives/primitives.dart';

/// Maps between the shared [BitcoinNetwork] primitive and the bwk FFI
/// `SpNetwork`. Silent Payments run on the same four networks, so the mapping
/// is total in both directions.
abstract final class SpNetworkMapper {
  static BitcoinNetwork toDomain(bwk.SpNetwork network) => switch (network) {
    bwk.SpNetwork.bitcoin => BitcoinNetwork.mainnet,
    bwk.SpNetwork.signet => BitcoinNetwork.signet,
    bwk.SpNetwork.testnet => BitcoinNetwork.testnet,
    bwk.SpNetwork.regtest => BitcoinNetwork.regtest,
  };

  static bwk.SpNetwork toFfi(BitcoinNetwork network) => switch (network) {
    BitcoinNetwork.mainnet => bwk.SpNetwork.bitcoin,
    BitcoinNetwork.signet => bwk.SpNetwork.signet,
    BitcoinNetwork.testnet => bwk.SpNetwork.testnet,
    BitcoinNetwork.regtest => bwk.SpNetwork.regtest,
  };
}
