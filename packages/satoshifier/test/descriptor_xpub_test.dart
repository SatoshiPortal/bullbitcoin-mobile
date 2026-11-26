import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

/// The extended public key travels inside a descriptor as an opaque
/// substring: the descriptor regex captures it and stores it verbatim, and
/// ExtendedPubkey.parse is never called on it. Nothing therefore verified its
/// base58check trailer, so a mistyped key produced a watch-only wallet on a
/// silently different key.
void main() {
  test('rejects a descriptor whose xpub fails base58check', () {
    final valid = TestValue.descriptorP2wpkhBip84;
    final i = TestValue.xpub.length ~/ 2;
    final badXpub = TestValue.xpub.replaceRange(
      i,
      i + 1,
      TestValue.xpub[i] == 'A' ? 'B' : 'A',
    );
    // Drop the checksum so only the key is wrong; otherwise the checksum
    // check would reject it first and prove nothing about the key.
    final descriptor = valid
        .replaceAll(TestValue.xpub, badXpub)
        .split('#')
        .first;
    expect(() => Descriptor.parse(descriptor), throwsA(anything));
  });

  test('rejects a bare key-origin xpub that fails base58check', () {
    final i = TestValue.xpub.length ~/ 2;
    final badXpub = TestValue.xpub.replaceRange(
      i,
      i + 1,
      TestValue.xpub[i] == 'A' ? 'B' : 'A',
    );

    expect(
      () => Descriptor.parse(
        '[${TestValue.walletMasterFingerprint}/84h/0h/0h]$badXpub',
      ),
      throwsA(anything),
    );
  });
}
