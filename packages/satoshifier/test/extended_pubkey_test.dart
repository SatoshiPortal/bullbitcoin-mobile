import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

void main() {
  group('ExtendedPubkey', () {
    test('parses xpub and pubBase58 matches input', () {
      final parsed = ExtendedPubkey.parse(TestValue.xpub);
      expect(parsed.pubBase58, TestValue.xpub);
      expect(parsed.fingerprint, TestValue.xpubFingerprint);
    });

    test('parses ypub and pubBase58 matches input', () {
      final parsed = ExtendedPubkey.parse(TestValue.ypub);

      expect(parsed.xpub, TestValue.ypubToXpub);
      expect(parsed.pubBase58, TestValue.ypub);
      expect(parsed.fingerprint, TestValue.ypubFingerprint);
    });

    test('parses zpub and pubBase58 matches input', () {
      final parsed = ExtendedPubkey.parse(TestValue.zpub);

      expect(parsed.pubBase58, TestValue.zpub);
      expect(parsed.fingerprint, TestValue.zpubFingerprint);
    });

    group('from descriptor', () {
      test('creates ExtendedPubkey from bip44 descriptor', () {
        final descriptor = Descriptor.parse(TestValue.descriptorP2pkhBip44);
        final extendedPubkey = ExtendedPubkey.parse(descriptor.pubkey);

        expect(extendedPubkey.pubBase58, TestValue.xpub);
        expect(extendedPubkey.fingerprint, TestValue.xpubFingerprint);

        expect(descriptor.derivation, extendedPubkey.derivation);
        expect(extendedPubkey.fingerprint, isNot(descriptor.fingerprint));
      });

      test('creates ExtendedPubkey from bip49 descriptor', () {
        final descriptor = Descriptor.parse(TestValue.descriptorP2shBip49);
        final extendedPubkey = ExtendedPubkey.parse(descriptor.pubkey);

        expect(extendedPubkey.pubBase58, TestValue.xpub);
        expect(extendedPubkey.fingerprint, TestValue.xpubFingerprint);

        expect(extendedPubkey.derivation, isNot(descriptor.derivation));
        expect(extendedPubkey.fingerprint, isNot(descriptor.fingerprint));
      });

      test('creates ExtendedPubkey from bip84 descriptor', () {
        final descriptor = Descriptor.parse(TestValue.descriptorP2wpkhBip84);
        final extendedPubkey = ExtendedPubkey.parse(descriptor.pubkey);

        expect(extendedPubkey.pubBase58, TestValue.xpub);
        expect(extendedPubkey.fingerprint, TestValue.xpubFingerprint);

        expect(extendedPubkey.derivation, isNot(descriptor.derivation));
        expect(extendedPubkey.fingerprint, isNot(descriptor.fingerprint));
      });
    });

    group('convert to other formats', () {
      test('converts bip49  xpub to ypub', () {
        final extendedPubkey = ExtendedPubkey.parse(TestValue.xpubBip49);
        final ypub = Bip32Utils.convertToYpub(extendedPubkey.pubkey);
        expect(ypub, TestValue.xpubBip49ToYpub);
      });

      test('converts bip84 xpub to zpub', () {
        final extendedPubkey = ExtendedPubkey.parse(TestValue.xpubBip84);
        final zpub = Bip32Utils.convertToZpub(extendedPubkey.pubkey);
        expect(zpub, TestValue.xpubBip84ToZpub);
      });
    });

    group('base58check validation', () {
      // Flipping a single character keeps the string well-formed base58 and
      // the right length, so only the checksum catches it. Without that
      // check the key parsed cleanly and produced a watch-only wallet on a
      // silently different key.
      String corrupt(String key) {
        final i = key.length ~/ 2;
        return key.replaceRange(i, i + 1, key[i] == 'A' ? 'B' : 'A');
      }

      for (final entry in {
        'xpub': TestValue.xpub,
        'ypub': TestValue.ypub,
        'zpub': TestValue.zpub,
      }.entries) {
        test('rejects a corrupted ${entry.key}', () {
          expect(
            () => ExtendedPubkey.parse(corrupt(entry.value)),
            throwsFormatException,
          );
        });

        test('still accepts a valid ${entry.key}', () {
          expect(ExtendedPubkey.parse(entry.value).pubBase58, entry.value);
        });
      }

      test('tryParse returns null on a corrupted key', () {
        expect(ExtendedPubkey.tryParse(corrupt(TestValue.xpub)), isNull);
      });

      test('rejects a truncated key', () {
        final truncated = TestValue.xpub.substring(
          0,
          TestValue.xpub.length - 4,
        );
        expect(() => ExtendedPubkey.parse(truncated), throwsFormatException);
      });
    });
  });
}
