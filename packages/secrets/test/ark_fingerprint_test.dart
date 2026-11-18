import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

void main() {
  late FakeSecureStoragePlatform storage;
  late Secrets secrets;

  setUp(() {
    storage = FakeSecureStoragePlatform(locked: true, writesFail: true)
      ..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
  });

  test('public zero-entropy vector keeps the Bark purpose identity', () async {
    final words = Mnemonic(List<int>.filled(16, 0), Language.english).words;
    final fingerprint = ok(await secrets.preview.arkFingerprint(words: words));
    // Independent BIP39/BIP32 m/350h vector, not the master fingerprint.
    expect(fingerprint.hex, '53bdf6b1');
    expect(storage.reads, 0);
    expect(storage.entries, isEmpty);
  });

  test('caller mutation cannot replace the admitted child', () async {
    final words = List<String>.of(
      Mnemonic(List<int>.filled(16, 0), Language.english).words,
    );
    final pending = secrets.preview.arkFingerprint(words: words);
    words.clear();
    expect(ok(await pending).hex, '53bdf6b1');
    expect(storage.reads, 0);
  });

  test(
    'invalid child returns a typed failure without touching storage',
    () async {
      final failure = err(
        await secrets.preview.arkFingerprint(words: ['invalid-child-input']),
      );
      expect(failure, isA<InvalidMnemonicFailure>());
      expect(failure.logMessage, isNot(contains('invalid-child-input')));
      expect(storage.reads, 0);
      expect(storage.entries, isEmpty);
    },
  );
}
