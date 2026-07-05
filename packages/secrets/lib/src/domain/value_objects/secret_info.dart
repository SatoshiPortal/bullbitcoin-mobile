import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The kind of stored secret a [SecretInfo] describes. The stored secret is
/// always a [mnemonic] today; [seed] is a dormant, ready seam for a future
/// bytes-only import path (decision: never built in the app yet).
enum SecretKind { mnemonic, seed }

/// NON-secret metadata about a stored secret. The richest thing a caller ever
/// learns about a wallet's key material without a sealed operation/widget — it
/// contains no words and no seed bytes. (The stored secret is always a
/// mnemonic today; a future seed-bytes variant would extend this.)
@immutable
class SecretInfo {
  const SecretInfo({
    required this.fingerprint,
    required this.kind,
    required this.wordCount,
    required this.hasPassphrase,
    required this.language,
    this.createdAt,
  });

  final Fingerprint fingerprint;

  /// Which kind of secret this indexes (mnemonic words vs. bytes seed).
  final SecretKind kind;

  final int wordCount;
  final bool hasPassphrase;

  /// BIP39 language name (e.g. `english`). A mnemonic always has one.
  final String language;

  /// Sourced from the app-side `SecretIndexPort`; null for legacy-migrated seeds.
  final DateTime? createdAt;

  @override
  bool operator ==(Object other) =>
      other is SecretInfo &&
      other.fingerprint == fingerprint &&
      other.kind == kind &&
      other.wordCount == wordCount &&
      other.hasPassphrase == hasPassphrase &&
      other.language == language &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
      fingerprint, kind, wordCount, hasPassphrase, language, createdAt);

  @override
  String toString() => 'SecretInfo(${fingerprint.hex}, ${kind.name}, '
      'words: $wordCount, passphrase: $hasPassphrase, $language)';
}
