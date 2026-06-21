import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/data/models/mnemonic.dart';

void main() {
  group('Mnemonic.fromStorageBytes — malformed input is an Exception', () {
    // The boundary _guard catches `on Exception`, NOT dart:core Error. A
    // malformed/legacy/forward-version blob must therefore surface as a
    // FormatException (Exception), never a StateError/TypeError/ArgumentError.
    test('non-JSON bytes → FormatException (not an Error)', () {
      expect(
        () => Mnemonic.fromStorageBytes(
            Uint8List.fromList(utf8.encode('not json'))),
        throwsA(isA<FormatException>()),
      );
    });

    test('JSON that is not an object → FormatException', () {
      expect(
        () => Mnemonic.fromStorageBytes(
            Uint8List.fromList(utf8.encode('[1,2,3]'))),
        throwsA(isA<FormatException>()),
      );
    });

    test('unknown kind → FormatException', () {
      expect(
        () => Mnemonic.fromStorageBytes(
            Uint8List.fromList(utf8.encode('{"kind":"alien"}'))),
        throwsA(isA<FormatException>()),
      );
    });

    test('unknown language falls back to english (no crash)', () {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode({
        'kind': 'mnemonic',
        'words': ['zoo', 'zoo', 'wrong'],
        'passphrase': null,
        'language': 'klingon',
      })));
      final secret = Mnemonic.fromStorageBytes(bytes);
      expect(secret, isA<Mnemonic>());
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
