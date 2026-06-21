import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/bip32_derivation.dart';
import 'package:secrets/src/domain/value_objects/seed_info.dart';

/// The in-package secret model. Holds the mnemonic words / raw bytes in
/// LIBRARY-PRIVATE fields so nothing outside this file reads them; nothing
/// outside `secrets` can import it at all (it lives under `src/`, never
/// exported). `toString` is redacted; there is no public `toJson` (only the
/// storage map for the [SecretStore], consumed internally).
sealed class SeedSecret {
  const SeedSecret();

  /// PBKDF2-derived 64-byte seed. Computing this touches the secret — keep its
  /// callers inside the crypto layer.
  Uint8List get seedBytes;

  SeedKind get kind;
  int? get wordCount;
  bool get hasPassphrase;

  /// 8-hex master fingerprint.
  String get fingerprintHex => Bip32Derivation.fingerprintHex(seedBytes);

  Fingerprint get fingerprint => Fingerprint(fingerprintHex);

  SeedInfo toInfo({DateTime? createdAt}) => SeedInfo(
        fingerprint: fingerprint,
        kind: kind,
        wordCount: wordCount,
        hasPassphrase: hasPassphrase,
        createdAt: createdAt,
      );

  /// The bytes persisted by the [SecretStore] (then base64-wrapped by the FSS
  /// backend). NOT a public API — internal storage encoding only.
  Uint8List toStorageBytes() =>
      Uint8List.fromList(utf8.encode(jsonEncode(_toMap())));

  Map<String, dynamic> _toMap();

  static SeedSecret fromStorageBytes(Uint8List bytes) {
    // Any malformed/legacy/forward-version blob must surface as a
    // FormatException (an Exception, caught by the boundary's `on Exception`)
    // — never a raw dart:core Error (StateError/TypeError/ArgumentError) that
    // would escape the repository/port `_guard` and crash the caller.
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('stored secret is not a JSON object');
      }
      switch (decoded['type']) {
        case 'mnemonic':
          return MnemonicSeedSecret(
            words: (decoded['words'] as List).cast<String>(),
            passphrase: decoded['passphrase'] as String?,
            language: bip39.Language.values.firstWhere(
              (l) => l.name == (decoded['language'] ?? 'english'),
              orElse: () => bip39.Language.english,
            ),
          );
        case 'bytes':
          return BytesSeedSecret(
            Uint8List.fromList(base64.decode(decoded['bytes'] as String)),
          );
        default:
          throw FormatException('Unknown SeedSecret type: ${decoded['type']}');
      }
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Malformed stored secret: $e');
    }
  }

  @override
  String toString() => 'SeedSecret($kind, words: $wordCount)'; // redacted
}

final class MnemonicSeedSecret extends SeedSecret {
  MnemonicSeedSecret({
    required List<String> words,
    String? passphrase,
    bip39.Language language = bip39.Language.english,
  })  : _words = List.unmodifiable(words),
        _passphrase = passphrase,
        _language = language;

  final List<String> _words;
  final String? _passphrase;
  final bip39.Language _language;

  /// Validates checksum eagerly (throws `MnemonicException` on bad input) and
  /// returns the PBKDF2 seed.
  @override
  Uint8List get seedBytes => Uint8List.fromList(
        bip39.Mnemonic.fromWords(
          words: _words,
          passphrase: _passphrase ?? '',
          language: _language,
        ).seed,
      );

  /// SECRET — in-package crypto/widget use only.
  List<String> get words => _words;
  String? get passphrase => _passphrase;
  bip39.Language get language => _language;

  @override
  SeedKind get kind => SeedKind.mnemonic;
  @override
  int get wordCount => _words.length;
  @override
  bool get hasPassphrase => _passphrase != null && _passphrase.isNotEmpty;

  @override
  Map<String, dynamic> _toMap() => {
        'type': 'mnemonic',
        'words': _words,
        'passphrase': _passphrase,
        'language': _language.name,
      };
}

final class BytesSeedSecret extends SeedSecret {
  BytesSeedSecret(Uint8List bytes) : _bytes = Uint8List.fromList(bytes);

  final Uint8List _bytes;

  @override
  Uint8List get seedBytes => Uint8List.fromList(_bytes);

  @override
  SeedKind get kind => SeedKind.bytesOnly;
  @override
  int? get wordCount => null;
  @override
  bool get hasPassphrase => false;

  @override
  Map<String, dynamic> _toMap() => {
        'type': 'bytes',
        'bytes': base64.encode(_bytes),
      };
}
