import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_path.dart';

/// Public inventory only. The private key is re-derived when it is used.
final class NostrKeyRecord {
  static const maxPurposeLength = 80;
  static const maxDescriptionLength = 200;

  final String parentFingerprint;
  final int identity;
  final String publicKey;
  final String purpose;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  NostrKeyRecord({
    required this.parentFingerprint,
    required this.identity,
    required this.publicKey,
    required this.purpose,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
  }) {
    nostrUserKeyPath(identity);
    if (!RegExp(r'^[0-9a-f]{8}$').hasMatch(parentFingerprint) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(publicKey) ||
        purpose.trim().isEmpty ||
        purpose != purpose.trim() ||
        purpose.length > maxPurposeLength ||
        description.length > maxDescriptionLength ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch('$purpose$description') ||
        updatedAt.isBefore(createdAt)) {
      throw const FormatException('Invalid Nostr key record');
    }
  }

  String get derivationPath => nostrUserKeyPath(identity);
}
