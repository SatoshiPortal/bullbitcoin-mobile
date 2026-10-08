import 'package:bb_mobile/features/sp/domain/entities/sp_header_checkpoint.dart';
import 'package:flutter_test/flutter_test.dart';

const checkpointHash =
    '000000000000000000001e39df127cbab82a824ac43cfcdbf62e59f6a08b9f0b';

SpHeaderCheckpoint buildCheckpoint({
  int height = 969696,
  String hash = checkpointHash,
}) => SpHeaderCheckpoint(height: height, hash: hash);

void main() {
  group('SpHeaderCheckpoint invariants', () {
    test('accepts a well formed checkpoint', () {
      final checkpoint = buildCheckpoint();

      expect(checkpoint.height, 969696);
      expect(checkpoint.hash, checkpointHash);
    });

    test('accepts height zero', () {
      expect(buildCheckpoint(height: 0).height, 0);
    });

    test('rejects a negative height', () {
      expect(() => buildCheckpoint(height: -1), throwsA(isA<ArgumentError>()));
    });

    test('rejects a hash one character short', () {
      expect(
        () => buildCheckpoint(hash: checkpointHash.substring(1)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a hash one character long', () {
      expect(
        () => buildCheckpoint(hash: '${checkpointHash}0'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects an uppercase hash', () {
      expect(
        () => buildCheckpoint(hash: checkpointHash.toUpperCase()),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a non hex character', () {
      expect(
        () => buildCheckpoint(hash: '${checkpointHash.substring(1)}g'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
