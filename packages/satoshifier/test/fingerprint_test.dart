import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

void main() {
  group('key-origin fingerprint', () {
    test('accepts exactly four bytes of hex, either case', () {
      expect(Descriptor.isValidFingerprint('86241f88'), isTrue);
      expect(Descriptor.isValidFingerprint('86241F88'), isTrue);
    });

    test('rejects anything else', () {
      expect(Descriptor.isValidFingerprint(''), isFalse);
      // Eight characters, but not hex: this is the value that used to parse and
      // then throw out of the canGeneratePsbt getter.
      expect(Descriptor.isValidFingerprint('zzzzzzzz'), isFalse);
      expect(Descriptor.isValidFingerprint('86241f8'), isFalse);
      expect(Descriptor.isValidFingerprint('86241f888'), isFalse);
      expect(Descriptor.isValidFingerprint('86241f8 '), isFalse);
    });

    test('a descriptor with a non-hex fingerprint does not parse', () {
      expect(
        () => Descriptor.parse('[zzzzzzzz/84h/0h/0h]${TestValue.xpub}'),
        throwsA(anything),
      );
      expect(
        () => Descriptor.fromStrings(
          fingerprint: 'zzzzzzzz',
          path: '84h/0h/0h',
          xpub: TestValue.xpub,
        ),
        throwsFormatException,
      );
    });

    test('a descriptor with a valid fingerprint still parses', () {
      final descriptor = Descriptor.fromStrings(
        fingerprint: TestValue.walletMasterFingerprint,
        path: '84h/0h/0h',
        xpub: TestValue.xpub,
      );
      expect(descriptor.fingerprint, TestValue.walletMasterFingerprint);
    });
  });
}
