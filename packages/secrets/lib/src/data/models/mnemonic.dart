import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/bip32_derivation.dart';
import 'package:secrets/src/domain/value_objects/seed_info.dart';

/// A derived BIP39 SEED — the 64-byte PBKDF2 output. Distinct from a
/// [Mnemonic]: a [Seed] is raw bytes (hex-representable) from which the words
/// CANNOT be recovered. SECRET, library-private bytes; never stored, never
/// exported. Produced by [Mnemonic.toSeed] and consumed by the crypto layer.
@immutable
class Seed {
  Seed(Uint8List bytes) : _bytes = Uint8List.fromList(bytes);
  final Uint8List _bytes;

  /// SECRET — in-package crypto use only (defensive copy).
  @internal
  Uint8List get bytes => Uint8List.fromList(_bytes);

  /// Hex representation (the only "view" of a seed — there are no words).
  @internal
  String get hex => _bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  @override
  String toString() => 'Seed(${_bytes.length} bytes)'; // redacted
}

/// The STORED secret: a BIP39 mnemonic — a list of [words], an optional
/// [passphrase], and a [language]. This is the ONLY kind of secret the package
/// persists today. The derived [Seed] (bytes) is computed on demand and is
/// never itself stored.
///
/// Library-private fields; nothing outside `secrets` can construct or read it
/// (it lives under `src/`, never exported). `toString` is redacted; there is no
/// public `toJson` — only the internal, versioned storage encoding below.
@immutable
class Mnemonic {
  Mnemonic({
    required List<String> words,
    String? passphrase,
    bip39.Language language = bip39.Language.english,
  })  : _words = List.unmodifiable(words),
        _passphrase = passphrase,
        _language = language;

  final List<String> _words;
  final String? _passphrase;
  final bip39.Language _language;

  /// SECRET — in-package crypto/widget use only.
  @internal
  List<String> get words => _words;
  @internal
  String? get passphrase => _passphrase;
  @internal
  bip39.Language get language => _language;

  int get wordCount => _words.length;
  bool get hasPassphrase => _passphrase != null && _passphrase.isNotEmpty;

  /// Derives the BIP39 [Seed] (validates checksum eagerly — throws
  /// `bip39.MnemonicException` on invalid words/checksum).
  @internal
  Seed toSeed() => Seed(
        Uint8List.fromList(
          bip39.Mnemonic.fromWords(
            words: _words,
            passphrase: _passphrase ?? '',
            language: _language,
          ).seed,
        ),
      );

  /// 8-hex master fingerprint (BIP32 over the derived seed).
  String get fingerprintHex => Bip32Derivation.fingerprintHex(toSeed().bytes);
  Fingerprint get fingerprint => Fingerprint(fingerprintHex);

  SeedInfo toInfo({DateTime? createdAt}) => SeedInfo(
        fingerprint: fingerprint,
        wordCount: wordCount,
        hasPassphrase: hasPassphrase,
        language: _language.name,
        createdAt: createdAt,
      );

  /// Bytes persisted by the SecretStorePort (base64-wrapped by the FSS adapter).
  /// Carries a `kind` discriminator so a future non-mnemonic stored secret
  /// (e.g. a raw imported seed) slots in without a format break. NOT a public
  /// API — internal storage encoding only.
  Uint8List toStorageBytes() => Uint8List.fromList(
        utf8.encode(jsonEncode({
          'kind': 'mnemonic',
          'words': _words,
          'passphrase': _passphrase,
          'language': _language.name,
        })),
      );

  /// Decodes a stored mnemonic — BACKWARD-COMPATIBLE across every on-disk format
  /// this wallet has ever written, so an existing user's seed is never lost when
  /// the app adopts this package (audit: data-migration). Recognizes:
  ///   1. this package's format        `{"kind":"mnemonic","words":[…],"language":…}`
  ///   2. the current app's SeedModel  `{"runtimeType":"mnemonic","mnemonicWords":[…],"passphrase":…}`
  ///   3. the pre-0.4 OldSeed          `{"mnemonic":"word word …","mnemonicFingerprint":…,"passphrases":[…]}`
  /// The master fingerprint (the storage key) is derivation-identical across all
  /// three (BIP39→BIP32), so a seed stored under the old format is found and read
  /// unchanged. Malformed/unsupported input surfaces as a `FormatException` (a
  /// catchable Exception) — never a `dart:core` Error that escapes the guard.
  static Mnemonic fromStorageBytes(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('stored secret is not a JSON object');
      }
      return _fromMap(decoded);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Malformed stored secret: $e');
    }
  }

  static Mnemonic _fromMap(Map<String, dynamic> m) {
    bip39.Language lang(Object? name) => bip39.Language.values.firstWhere(
          (l) => l.name == (name ?? 'english'),
          orElse: () => bip39.Language.english,
        );

    // 1. This package's native format.
    if (m['kind'] == 'mnemonic') {
      return Mnemonic(
        words: (m['words'] as List).cast<String>(),
        passphrase: m['passphrase'] as String?,
        language: lang(m['language']),
      );
    }
    // 2. The current app's SeedModel JSON (freezed: `runtimeType` + `mnemonicWords`).
    if (m['runtimeType'] == 'mnemonic' || m.containsKey('mnemonicWords')) {
      return Mnemonic(
        words: (m['mnemonicWords'] as List).cast<String>(),
        passphrase: m['passphrase'] as String?,
      );
    }
    // 3. The pre-0.4 OldSeed JSON (single space-joined string). This blob is
    //    keyed by the BARE-mnemonic fingerprint (`mnemonicFingerprint`), so it
    //    represents the bare mnemonic — passphrase MUST be null. The old model's
    //    `passphrases` list is wallet-level metadata for DERIVED wallets (each
    //    migrated by 005 into its own passphrase-fingerprinted SeedModel, read
    //    by case 2); attaching one here would derive a different fingerprint
    //    than this key → an unfindable seed. So we never guess a passphrase.
    if (m['mnemonic'] is String && (m['mnemonic'] as String).isNotEmpty) {
      final words = (m['mnemonic'] as String).trim().split(RegExp(r'\s+'));
      return Mnemonic(words: words);
    }
    // A bytes-only seed (`runtimeType:"bytes"`) was never created in practice
    // (zero callers) and this package stores only mnemonics — reject it
    // explicitly and SAFELY (surfaced, never silently treated as a valid seed).
    if (m['runtimeType'] == 'bytes' || m.containsKey('bytes')) {
      throw const FormatException('bytes-only seeds are not supported');
    }
    throw const FormatException('unrecognized stored-secret format');
  }

  @override
  String toString() => 'Mnemonic($wordCount words, '
      'passphrase: $hasPassphrase, ${_language.name})'; // words redacted
}
