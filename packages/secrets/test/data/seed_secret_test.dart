import 'package:secrets/src/data/datasources/malformed_secret_exception.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/data/models/mnemonic.dart';

void main() {
  group('Mnemonic.fromStorageBytes — malformed input is an Exception', () {
    // The boundary _guard catches `on Exception`, NOT dart:core Error. A
    // malformed/legacy/forward-version blob must therefore surface as a
    // MalformedSecretException (Exception), never a StateError/TypeError/ArgumentError.
    test('non-JSON bytes → MalformedSecretException (not an Error)', () {
      expect(
        () => Mnemonic.fromStorageBytes(
            Uint8List.fromList(utf8.encode('not json'))),
        throwsA(isA<MalformedSecretException>()),
      );
    });

    test('JSON that is not an object → MalformedSecretException', () {
      expect(
        () => Mnemonic.fromStorageBytes(
            Uint8List.fromList(utf8.encode('[1,2,3]'))),
        throwsA(isA<MalformedSecretException>()),
      );
    });

    test('unknown kind → MalformedSecretException', () {
      expect(
        () => Mnemonic.fromStorageBytes(
            Uint8List.fromList(utf8.encode('{"kind":"alien"}'))),
        throwsA(isA<MalformedSecretException>()),
      );
    });

    test('an EXPLICIT unknown language → MalformedSecretException (versioning)',
        () {
      // Silently defaulting an unknown language to English would derive a
      // DIFFERENT seed (wrong wordlist) under the same fingerprint, so it must
      // surface as malformed (a versioning/format problem), not be guessed.
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode({
        'kind': 'mnemonic',
        'words': ['zoo', 'zoo', 'wrong'],
        'passphrase': null,
        'language': 'klingon',
      })));
      expect(() => Mnemonic.fromStorageBytes(bytes),
          throwsA(isA<MalformedSecretException>()));
    });

    test('a MISSING language field defaults to english (legacy compat)', () {
      // Distinct from an explicit-unknown language: legacy blobs simply omit the
      // field, and English is the correct, fingerprint-preserving default.
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode({
        'kind': 'mnemonic',
        'words': ['zoo', 'zoo', 'wrong'],
      })));
      final secret = Mnemonic.fromStorageBytes(bytes);
      expect(secret.language, bip39.Language.english);
      expect(secret.words, ['zoo', 'zoo', 'wrong']);
    });

    test('empty word list → MalformedSecretException (native format)', () {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode({
        'kind': 'mnemonic',
        'words': <String>[],
      })));
      expect(() => Mnemonic.fromStorageBytes(bytes),
          throwsA(isA<MalformedSecretException>()));
    });

    test('empty word list → MalformedSecretException (app SeedModel format)', () {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode({
        'runtimeType': 'mnemonic',
        'mnemonicWords': <String>[],
      })));
      expect(() => Mnemonic.fromStorageBytes(bytes),
          throwsA(isA<MalformedSecretException>()));
    });
  });

  group('round-trip', () {
    test('mnemonic with passphrase round-trips', () {
      final original = Mnemonic(
        words: const ['zoo', 'zoo', 'wrong'],
        passphrase: 'secret',
      );
      final restored = Mnemonic.fromStorageBytes(original.toStorageBytes());
      expect(restored.words, original.words);
      expect(restored.passphrase, 'secret');
      expect(restored.hasPassphrase, isTrue);
    });

    test('language round-trips', () {
      final original = Mnemonic(
        words: const ['zoo', 'zoo', 'wrong'],
        language: bip39.Language.french,
      );
      final restored = Mnemonic.fromStorageBytes(original.toStorageBytes());
      expect(restored.language, bip39.Language.french);
    });
  });
}
