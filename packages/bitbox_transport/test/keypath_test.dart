import 'package:bitbox_transport/bitbox_transport.dart';
import 'package:flutter_test/flutter_test.dart';

/// The SLIP-132 prefix of an extended public key encodes the script type the
/// key is meant to derive. Asking a BitBox02 for an `xpub` on a BIP84 keypath
/// returns a key that a consumer will read as legacy, producing a watch-only
/// wallet on addresses the device will never recognise. The purpose in the
/// keypath is the authoritative signal, so derive from it.
void main() {
  group('xpubTypeForKeypath', () {
    test('maps BIP84 to zpub', () {
      expect(BitBoxKeypath.xpubTypeFor("m/84'/0'/0'"), 'zpub');
      expect(BitBoxKeypath.xpubTypeFor('m/84h/0h/0h'), 'zpub');
    });

    test('maps BIP49 to ypub', () {
      expect(BitBoxKeypath.xpubTypeFor("m/49'/0'/0'"), 'ypub');
      expect(BitBoxKeypath.xpubTypeFor('m/49h/0h/0h'), 'ypub');
    });

    test('maps BIP44 to xpub', () {
      expect(BitBoxKeypath.xpubTypeFor("m/44'/0'/0'"), 'xpub');
      expect(BitBoxKeypath.xpubTypeFor('m/44h/0h/0h'), 'xpub');
    });

    test('accepts a keypath without the leading m/', () {
      expect(BitBoxKeypath.xpubTypeFor("84'/0'/0'"), 'zpub');
    });

    test('refuses to guess for an unknown purpose', () {
      // Taproot (BIP86) has no SLIP-132 prefix, and an unrecognised purpose
      // must not silently fall back to xpub — that is the original bug.
      expect(
        () => BitBoxKeypath.xpubTypeFor("m/86'/0'/0'"),
        throwsArgumentError,
      );
      expect(() => BitBoxKeypath.xpubTypeFor('nonsense'), throwsArgumentError);
      expect(() => BitBoxKeypath.xpubTypeFor(''), throwsArgumentError);
    });
  });
}
