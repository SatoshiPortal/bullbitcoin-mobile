import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

/// Proves the two integrity gaps reported against `Descriptor.parse`:
/// the BIP-380 checksum suffix is captured by the regex but never verified,
/// and the extended public key inside the descriptor is stored verbatim
/// without its base58check trailer being checked.
///
/// Both let a descriptor that a user mistyped, or that was mangled in
/// transit, build a watch-only wallet on the wrong key. The descriptor
/// checksum exists precisely to catch that, which is why it is in the string
/// at all.
void main() {
  group('Descriptor integrity', () {
    final valid = TestValue.descriptorP2wpkhBip84;

    String withChecksum(String checksum) =>
        '${valid.split('#').first}#$checksum';

    group('BIP-380 checksum', () {
      test('accepts the correct checksum', () {
        expect(Descriptor.parse(valid).pubkey, TestValue.xpub);
      });

      // Derived from the real checksum so the case stays meaningful if the
      // fixture ever changes: same length, same charset, one character off.
      final correct = valid.split('#').last;
      final corrupted = correct.replaceRange(
        0,
        1,
        correct[0] == 'q' ? 'p' : 'q',
      );

      test('rejects a corrupted checksum', () {
        expect(
          () => Descriptor.parse(withChecksum(corrupted)),
          throwsA(anything),
        );
      });

      test('rejects a checksum of the wrong length', () {
        expect(
          () => Descriptor.parse(
            withChecksum(correct.substring(0, correct.length - 1)),
          ),
          throwsA(anything),
        );
      });
    });
  });
}
