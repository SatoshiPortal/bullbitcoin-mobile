import 'package:bb_mobile/features/sp/data/mappers/sp_network_mapper.dart';
import 'package:bull_sdk/bwk.dart' as bwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  group('SpNetworkMapper', () {
    test('maps every bwk network to its primitive', () {
      expect(
        SpNetworkMapper.toDomain(bwk.SpNetwork.bitcoin),
        BitcoinNetwork.mainnet,
      );
      expect(
        SpNetworkMapper.toDomain(bwk.SpNetwork.signet),
        BitcoinNetwork.signet,
      );
      expect(
        SpNetworkMapper.toDomain(bwk.SpNetwork.testnet),
        BitcoinNetwork.testnet,
      );
      expect(
        SpNetworkMapper.toDomain(bwk.SpNetwork.regtest),
        BitcoinNetwork.regtest,
      );
    });

    test('maps every primitive network to its bwk value', () {
      expect(
        SpNetworkMapper.toFfi(BitcoinNetwork.mainnet),
        bwk.SpNetwork.bitcoin,
      );
      expect(
        SpNetworkMapper.toFfi(BitcoinNetwork.signet),
        bwk.SpNetwork.signet,
      );
      expect(
        SpNetworkMapper.toFfi(BitcoinNetwork.testnet),
        bwk.SpNetwork.testnet,
      );
      expect(
        SpNetworkMapper.toFfi(BitcoinNetwork.regtest),
        bwk.SpNetwork.regtest,
      );
    });

    test('round-trips every bwk network', () {
      for (final network in bwk.SpNetwork.values) {
        expect(
          SpNetworkMapper.toFfi(SpNetworkMapper.toDomain(network)),
          network,
        );
      }
    });

    test('round-trips every primitive network', () {
      for (final network in BitcoinNetwork.values) {
        expect(
          SpNetworkMapper.toDomain(SpNetworkMapper.toFfi(network)),
          network,
        );
      }
    });
  });
}
