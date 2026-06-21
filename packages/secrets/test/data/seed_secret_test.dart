import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/data/models/seed_secret.dart';

void main() {
  group('SeedSecret.fromStorageBytes — malformed input is an Exception', () {
    // The boundary _guard catches `on Exception`, NOT dart:core Error. A
    // malformed/legacy/forward-version blob must therefore surface as a
    // FormatException (Exception), never a StateError/TypeError/ArgumentError.
    test('non-JSON bytes → FormatException (not an Error)', () {
      expect(
        () => SeedSecret.fromStorageBytes(
            Uint8List.fromList(utf8.encode('not json'))),
        throwsA(isA<FormatException>()),
      );
    });

    test('JSON that is not an object → FormatException', () {
      expect(
        () => SeedSecret.fromStorageBytes(
            Uint8List.fromList(utf8.encode('[1,2,3]'))),
        throwsA(isA<FormatException>()),
      );
    });

    test('unknown type → FormatException', () {
      expect(
        () => SeedSecret.fromStorageBytes(
            Uint8List.fromList(utf8.encode('{"type":"alien"}'))),
        throwsA(isA<FormatException>()),
      );
    });

    test('unknown language falls back to english (no crash)', () {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode({
        'type': 'mnemonic',
        'words': ['zoo', 'zoo', 'wrong'],
        'passphrase': null,
        'language': 'klingon',
      })));
      final secret = SeedSecret.fromStorageBytes(bytes);
      expect(secret, isA<MnemonicSeedSecret>());
    });
  });

  group('round-trip', () {
    test('mnemonic with passphrase round-trips', () {
      final original = MnemonicSeedSecret(
        words: const ['zoo', 'zoo', 'wrong'],
        passphrase: 'secret',
      );
      final restored =
          SeedSecret.fromStorageBytes(original.toStorageBytes())
              as MnemonicSeedSecret;
      expect(restored.words, original.words);
      expect(restored.passphrase, 'secret');
      expect(restored.hasPassphrase, isTrue);
    });

    test('bytes seed round-trips', () {
      final original = BytesSeedSecret(Uint8List.fromList(List.filled(32, 5)));
      final restored =
          SeedSecret.fromStorageBytes(original.toStorageBytes());
      expect(restored.kind.name, 'bytesOnly');
      expect(restored.seedBytes, original.seedBytes);
    });
  });
}
