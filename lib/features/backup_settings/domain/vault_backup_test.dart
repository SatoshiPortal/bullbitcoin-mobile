import 'dart:convert';
import 'package:crypto/crypto.dart';

enum VaultBackupSource { manual, metadata, bip138, nostr, bitcoin }

/// A successful retrieval, scoped to one complete descriptor and one source.
final class VaultBackupTest {
  /// Recovery-package IDs may include optional birth-height metadata. Test
  /// receipts belong to the actual descriptor, independent of its wrapper.
  static String identity(String canonicalDescriptor, String network) =>
      sha256.convert(utf8.encode('$network|$canonicalDescriptor')).toString();
  final String descriptorId;
  final VaultBackupSource source;
  final DateTime verifiedAt;
  VaultBackupTest({
    required this.descriptorId,
    required this.source,
    required DateTime verifiedAt,
  }) : verifiedAt = verifiedAt.toUtc() {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(descriptorId)) {
      throw ArgumentError('Invalid descriptor identity');
    }
  }
}
