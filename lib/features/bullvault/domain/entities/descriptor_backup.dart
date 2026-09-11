import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup_key.dart';

final class DescriptorBackup {
  final String descriptor;
  final Uint8List bytes;
  final List<DescriptorBackupRecipient> recipients;
  DescriptorBackup(
    this.descriptor,
    Uint8List bytes,
    List<DescriptorBackupRecipient> recipients,
  ) : bytes = Uint8List.fromList(bytes).asUnmodifiableView(),
      recipients = List.unmodifiable(recipients);
}

final class DescriptorBackupRecipient {
  final DescriptorBackupKey key;
  final String lookup;
  final String encryptedContent;
  const DescriptorBackupRecipient(this.key, this.lookup, this.encryptedContent);
}

/// Public signing request; no serialization or private key crosses this boundary.
final class DescriptorBackupPublication {
  final DescriptorBackupRecipient recipient;
  final String author;
  final int createdAt;
  final String hash;
  const DescriptorBackupPublication(
    this.recipient,
    this.author,
    this.createdAt,
    this.hash,
  );
}

final class RecoveredDescriptorBackup {
  final String descriptor;
  final String eventId;
  final Uint8List bytes;
  RecoveredDescriptorBackup(this.descriptor, this.eventId, Uint8List bytes)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
}

final class DescriptorBackupFetch {
  final List<RecoveredDescriptorBackup> candidates;
  final bool incomplete;
  final int rejectedEvents;
  DescriptorBackupFetch(
    List<RecoveredDescriptorBackup> candidates, {
    required this.incomplete,
    required this.rejectedEvents,
  }) : candidates = List.unmodifiable(candidates);
}

/// Compatibility name for the shared relay cancellation session.
typedef DescriptorBackupSession = NostrSession;
