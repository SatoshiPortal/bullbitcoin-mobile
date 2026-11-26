import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';

// BIP32 test vector 1, master private key: public, funds-free.
const _xprv =
    'xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi';

// BIP32 test vector 1 on testnet, master private key: public, funds-free.
const _tprv =
    'tprv8ZgxMBicQKsPeDgjzdC36fs6bMjGApWDNLR9erAXMs5skhMv36j9MV5ecvfavji5khqjWaWSFhN3YcCUUdiKH6isR4Pwy3U5y5egddBr16m';

void main() {
  test('a descriptor never accepts a testnet private extended key', () {
    expect(
      () => Descriptor.fromStrings(
        fingerprint: '3442193e',
        path: '84h/1h/0h',
        xpub: _tprv,
      ),
      throwsFormatException,
    );
  });

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
