import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/crypto/signers/bitcoin_signer.dart';

/// The release discipline, on its own: every bdk handle is freed even when
/// one refuses, and the first refusal is what the caller learns about. Pure
/// Dart — the releases are tear-offs, so no FFI is needed to exercise it.
void main() {
  group('BitcoinSigner.disposeAll', () {
    test('runs every release even after one throws, and reports the first', () {
      final released = <String>[];
      final failure = BitcoinSigner.disposeAll([
        () => released.add('a'),
        () => throw StateError('b refused'),
        () => released.add('c'),
        () => throw StateError('d refused'),
      ]);

      expect(released, ['a', 'c'], reason: 'one refusal skips nothing');
      expect(
        failure?.error,
        isA<StateError>().having((e) => e.message, 'message', 'b refused'),
      );
    });

    test('returns null when every release succeeds', () {
      expect(BitcoinSigner.disposeAll([() {}, () {}]), isNull);
    });

    test('an empty list is nothing to release', () {
      expect(BitcoinSigner.disposeAll(const []), isNull);
    });
  });
}
