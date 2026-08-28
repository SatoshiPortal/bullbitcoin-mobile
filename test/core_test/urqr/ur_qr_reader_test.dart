import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/urqr/urqr.dart';
import 'package:cbor/cbor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur/ur.dart';
import 'package:ur/ur_encoder.dart';

void main() {
  group('UrQrReader', () {
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
  });
}
