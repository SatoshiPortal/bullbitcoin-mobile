import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/urqr/urqr.dart';
import 'package:cbor/cbor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur/ur.dart';
import 'package:ur/ur_encoder.dart';

void main() {
  group('UrQrReader', () {
    test('generator rejects streams beyond the reader limit', () {
      final psbt = base64.encode(Uint8List(100000));

      expect(
        () => UrQrGenerator.generatePsbtUr(psbt),
        throwsA(isA<UrSequenceLimitExceeded>()),
      );
    });

    // Animated URs are fountain-coded (BCR-2020-005): once the pure
    // fragments 1..N have played, the stream keeps emitting mixed parts
    // N+1, N+2, ... The reader must accept them, or any scan that joins
    // the animation mid-stream fails immediately.
    test('decodes a stream the camera joins mid-animation', () {
      final payload = cbor.encode(CborBytes(utf8.encode('x' * 100)));
      final encoder = UREncoder(UR('bytes', Uint8List.fromList(payload)), 20);
      final pureParts = <String>[];
      while (!encoder.isComplete) {
        pureParts.add(encoder.nextPart());
      }
      final mixedPart = encoder.nextPart(); // seqNum N+1 of N

      final reader = UrQrReader();
      reader.receive(mixedPart); // first captured frame is a mixed part
      for (final part in pureParts) {
        reader.receive(part);
      }

      expect(reader.isComplete, isTrue);
    });

    test('infers testnet from the key origin when use info is absent', () {
      const parts = [
        'UR:CRYPTO-ACCOUNT/1-4/LPADAACSKPCYMOMNLGRYHDCKOEADCYSSMECPONAOLYTAADMETAADDLOXAXHDCLAOKSRLNLKPUEGYATHPMNSNIYMUECBY',
        'UR:CRYPTO-ACCOUNT/2-4/LPAOAACSKPCYMOMNLGRYHDCKKKGHZMLUZORPVDGUOTECSTTKTOLPCWPTNTLKZTTIZTBEAAHDCXVDTPMYRSTDMOPSCXFZ',
        'UR:CRYPTO-ACCOUNT/3-4/LPAXAACSKPCYMOMNLGRYHDCKSPZSBZSPGERLGDATUYNLPYBTGYIYYKBTWTAOSWKSVTSGCHBYDKYAVDAMTAADMONDGDFD',
        'UR:CRYPTO-ACCOUNT/4-4/LPAAAACSKPCYMOMNLGRYHDCKDYOTADLOCSDYYKADYKAEYKAOYKAOCYSSMECPONAXAAAYCYIOREKKJKAEAEAEWZWDMYON',
      ];
      final reader = UrQrReader();

      for (final part in parts) {
        reader.receive(part);
      }

      final account = reader.decoded! as CryptoAccount;
      expect(account.hdKey!.derivationPath, 'm/48h/1h/0h/2h');
      expect(account.hdKey!.network, HdKeyNetwork.testnet);
      expect(account.hdKey!.xpub, startsWith('tpub'));
    });

    test('keeps the mainnet fallback for an unhardened child index', () {
      final key = CryptoHdKey.fromCborMap({
        3: CborBytes(Uint8List(33)),
        4: CborBytes(Uint8List(32)),
        6: CborMap({
          const CborSmallInt(1): CborList(const [
            CborSmallInt(84),
            CborBool(true),
            CborSmallInt(1),
            CborBool(false),
          ]),
        }),
      });

      expect(key.network, HdKeyNetwork.mainnet);
    });
  });
}
