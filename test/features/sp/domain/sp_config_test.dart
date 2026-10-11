import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  group('SpConfig.headerCheckpoint', () {
    test('mainnet is pinned to block 969696', () {
      final checkpoint = SpConfig.headerCheckpoint(BitcoinNetwork.mainnet);

      expect(checkpoint, isNotNull);
      expect(checkpoint!.height, 969696);
      expect(
        checkpoint.hash,
        '000000000000000000001e39df127cbab82a824ac43cfcdbf62e59f6a08b9f0b',
      );
    });

    for (final network in [
      BitcoinNetwork.signet,
      BitcoinNetwork.testnet,
      BitcoinNetwork.regtest,
    ]) {
      test('${network.name} has no checkpoint', () {
        expect(SpConfig.headerCheckpoint(network), isNull);
      });
    }
  });
}
