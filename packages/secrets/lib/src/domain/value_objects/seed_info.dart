import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// NON-secret metadata about a stored mnemonic. The richest thing a caller ever
/// learns about a wallet's key material without a sealed operation/widget — it
/// contains no words and no seed bytes. (The stored secret is always a
/// mnemonic today; a future seed-bytes variant would extend this.)
@immutable
class SeedInfo {
  const SeedInfo({
    required this.fingerprint,
    required this.wordCount,
    required this.hasPassphrase,
    required this.language,
    this.createdAt,
  });

  final Fingerprint fingerprint;
  final int wordCount;
  final bool hasPassphrase;

  /// BIP39 language name (e.g. `english`). A mnemonic always has one.
  final String language;

  /// Sourced from the app-side `SeedIndexPort`; null for legacy-migrated seeds.
  final DateTime? createdAt;

  @override
  bool operator ==(Object other) =>
      other is SeedInfo &&
      other.fingerprint == fingerprint &&
      other.wordCount == wordCount &&
      other.hasPassphrase == hasPassphrase &&
      other.language == language &&
      other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(fingerprint, wordCount, hasPassphrase, language, createdAt);

  @override
  String toString() => 'SeedInfo(${fingerprint.hex}, words: $wordCount, '
      'passphrase: $hasPassphrase, $language)';
}
