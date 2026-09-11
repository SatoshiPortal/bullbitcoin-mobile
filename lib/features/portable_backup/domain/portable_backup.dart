import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';

enum PortableBackupKind { metadata, vault }

final class PortableBackupArtifact {
  final PortableBackupKind kind;
  final String network;
  final String contents;
  PortableBackupArtifact({
    required this.kind,
    required this.network,
    required this.contents,
  }) {
    if (kind == PortableBackupKind.vault && contents.length > 24000) {
      throw const FormatException('Descriptor too large');
    }
    if (!const {
          'bitcoin',
          'testnet',
          'testnet4',
          'signet',
          'regtest',
        }.contains(network) ||
        contents.isEmpty) {
      throw const FormatException('Invalid portable backup');
    }
  }
}

final class PortableBackupFiles {
  final Uint8List metadata;
  final Uint8List vault;
  PortableBackupFiles({required Uint8List metadata, required Uint8List vault})
    : metadata = Uint8List.fromList(metadata).asUnmodifiableView(),
      vault = Uint8List.fromList(vault).asUnmodifiableView();
}

final class PortableBackupCandidate {
  final PortableBackupArtifact artifact;
  final String eventId;
  final Uint8List encryptedFile;
  PortableBackupCandidate({
    required this.artifact,
    required this.eventId,
    required Uint8List encryptedFile,
  }) : encryptedFile = Uint8List.fromList(encryptedFile).asUnmodifiableView();
}

final class PortableBackupFetch {
  final List<PortableBackupCandidate> candidates;
  final bool incomplete;
  final int rejectedEvents;
  PortableBackupFetch({
    required List<PortableBackupCandidate> candidates,
    required this.incomplete,
    required this.rejectedEvents,
  }) : candidates = List.unmodifiable(candidates);
}

/// The encrypted files remain exportable even if the relay rejects publication.
final class PortableBackupPublication {
  final PortableBackupFiles files;
  final Result<String, PortableBackupFailure> publication;

  const PortableBackupPublication({
    required this.files,
    required this.publication,
  });
}
