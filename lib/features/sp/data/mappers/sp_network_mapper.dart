import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bull_sdk/bwk.dart' as bwk;

/// Maps between the domain [SpNetwork] and the bwk FFI `SpNetwork`.
abstract final class SpNetworkMapper {
  static SpNetwork toDomain(bwk.SpNetwork network) => switch (network) {
    bwk.SpNetwork.bitcoin => SpNetwork.bitcoin,
    bwk.SpNetwork.signet => SpNetwork.signet,
    bwk.SpNetwork.testnet => SpNetwork.testnet,
    bwk.SpNetwork.regtest => SpNetwork.regtest,
  };

  static bwk.SpNetwork toFfi(SpNetwork network) => switch (network) {
    SpNetwork.bitcoin => bwk.SpNetwork.bitcoin,
    SpNetwork.signet => bwk.SpNetwork.signet,
    SpNetwork.testnet => bwk.SpNetwork.testnet,
    SpNetwork.regtest => bwk.SpNetwork.regtest,
  };
}
