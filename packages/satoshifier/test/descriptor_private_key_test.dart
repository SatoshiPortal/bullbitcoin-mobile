import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';

// BIP32 test vector 1, master private key: public, funds-free.
const _xprv =
    'xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi';

void main() {
  test('a descriptor never accepts a private extended key', () {
    expect(
      () => Descriptor.fromStrings(
        fingerprint: '3442193e',
        path: '84h/0h/0h',
        xpub: _xprv,
      ),
      throwsFormatException,
    );
    expect(
      () => Descriptor.fromExternalDescriptor(
        'wpkh([3442193e/84h/0h/0h]$_xprv/0/*)',
      ),
      throwsFormatException,
    );
  });
}
