import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';
import 'package:bb_mobile/features/wallet/data/wallet_network_codec.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' as primitives;

void main() {
  group('persisted identity', () {
    // One codec, one plain-text column: `WalletNetworkCodec` is the only Dart encoder and decoder of the Drift `wallet_metadatas.network` column (it has no Drift converter), and the migrations and seeds write the identical strings as SQL literals.
    // The column defaults to `unresolved`, which the codec refuses.
    test('WalletNetworkCodec names equal the enum names', () {
      for (final network in Network.values) {
        expect(
          WalletNetworkCodec.encode(network),
          network.name,
          reason: network.name,
        );
        expect(WalletNetworkCodec.decode(network.name), network);
      }
    });

    test('decode refuses every value the column can hold besides a name', () {
      // 'unresolved' is the Drift column default and the migration's marker
      // for a row whose origin could not be read; it fails closed.
      for (final rejected in [
        'unresolved',
        'signet',
        'bitcoinSignet',
        'BitcoinMainnet',
        'bitcoinMainnet ',
        '',
        '0',
      ]) {
        expect(
          () => WalletNetworkCodec.decode(rejected),
          throwsFormatException,
          reason: rejected,
        );
      }
    });
  });

  group('WalletMetadataService', () {
    const fingerprint = 'aabbccdd';

    test('encodeOrigin stores 0h, 1h or 1776h plus an el prefix on Liquid', () {
      const expected = <Network, String>{
        Network.bitcoinMainnet: 'wpkh([aabbccdd/84h/0h/0h])',
        Network.bitcoinTestnet: 'wpkh([aabbccdd/84h/1h/0h])',
        Network.bitcoinRegtest: 'wpkh([aabbccdd/84h/1h/0h])',
        Network.liquidMainnet: 'elwpkh([aabbccdd/84h/1776h/0h])',
        Network.liquidTestnet: 'elwpkh([aabbccdd/84h/1h/0h])',
        Network.liquidRegtest: 'elwpkh([aabbccdd/84h/1h/0h])',
      };
      for (final network in Network.values) {
        expect(
          WalletMetadataService.encodeOrigin(
            fingerprint: fingerprint,
            network: network,
            scriptType: primitives.ScriptType.bip84,
          ),
          expected[network],
          reason: network.name,
        );
      }
    });

    test('decodeOrigin cannot recover regtest from a stored origin', () {
      // Frozen on purpose: coin type 1 is shared by every test family, so a
      // stored origin reports testnet. Only the id suffix distinguishes
      // regtest, and that suffix is stripped before parsing.
      for (final (stored, decoded) in [
        (Network.bitcoinMainnet, Network.bitcoinMainnet),
        (Network.bitcoinTestnet, Network.bitcoinTestnet),
        (Network.liquidTestnet, Network.liquidTestnet),
        (Network.liquidMainnet, Network.liquidMainnet),
        (Network.bitcoinRegtest, Network.bitcoinTestnet),
        (Network.liquidRegtest, Network.liquidTestnet),
      ]) {
        final origin = WalletMetadataService.encodeOrigin(
          fingerprint: fingerprint,
          network: stored,
          scriptType: primitives.ScriptType.bip84,
        );
        expect(
          WalletMetadataService.decodeOrigin(origin: origin).network,
          decoded,
          reason: stored.name,
        );
      }
    });

    test('encodeId marks only regtest with a suffix', () {
      for (final network in Network.values) {
        final id = WalletMetadataService.encodeId(
          fingerprint: fingerprint,
          network: network,
          scriptType: primitives.ScriptType.bip84,
        );
        final origin = WalletMetadataService.encodeOrigin(
          fingerprint: fingerprint,
          network: network,
          scriptType: primitives.ScriptType.bip84,
        );
        expect(
          id,
          network.name.contains('Regtest') ? '$origin:regtest' : origin,
          reason: network.name,
        );
        expect(WalletMetadataService.originFromId(id), origin);
      }
    });
  });
}
