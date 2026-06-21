import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Whether a stored seed is a BIP39 mnemonic or raw bytes.
enum SeedKind { mnemonic, bytesOnly }

/// NON-secret metadata about a stored seed. This is the richest thing a caller
/// ever learns about a seed without going through a sealed operation/widget —
/// it contains no mnemonic words and no seed bytes.
@immutable
class SeedInfo {
  const SeedInfo({
    required this.fingerprint,
    required this.kind,
    required this.hasPassphrase,
    this.wordCount,
    this.createdAt,
  });

  final Fingerprint fingerprint;
  final SeedKind kind;

  /// Null for [SeedKind.bytesOnly].
  final int? wordCount;
  final bool hasPassphrase;

  /// Sourced from the app-side `SeedIndex`; null for legacy-migrated seeds.
  final DateTime? createdAt;

  @override
  bool operator ==(Object other) =>
      other is SeedInfo &&
      other.fingerprint == fingerprint &&
      other.kind == kind &&
      other.wordCount == wordCount &&
      other.hasPassphrase == hasPassphrase &&
      other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(fingerprint, kind, wordCount, hasPassphrase, createdAt);

  @override
  String toString() =>
      'SeedInfo(${fingerprint.hex}, $kind, words: $wordCount, '
      'passphrase: $hasPassphrase)';
}
