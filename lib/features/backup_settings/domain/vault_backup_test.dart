import 'dart:convert';
import 'package:crypto/crypto.dart';

enum VaultBackupSource { manual, metadata, bip138, nostr, bitcoin }

/// What the most recent check of one source did, beside its historical date.
///
/// Only [success] ever moves a date. [incomplete] is the honest answer when a
/// source could not be read to the end, and is not the same as [failed]: the
/// vault may be there, unseen.
enum VaultBackupCheckStatus { success, failed, unavailable, incomplete }

/// The latest attempt per source. A source that was not checked is absent.
typedef VaultBackupCheckResults =
    Map<VaultBackupSource, VaultBackupCheckStatus>;

/// What a BIP138 check found, counted over the vault's eligible cosigners.
///
/// A receipt is recorded only when every one of them could retrieve and open
/// the descriptor: a vault where two of three cosigners can
/// recover is not a vault with a backup. The partial counts are for telling the
/// person which is which, and are never persisted.
final class VaultBackupBip138Check {
  final int eligibleKeys;
  final int foundKeys;
  final bool incomplete;

  const VaultBackupBip138Check({
    required this.eligibleKeys,
    required this.foundKeys,
    required this.incomplete,
  });

  bool get complete => eligibleKeys > 0 && foundKeys == eligibleKeys;
}

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
