import 'dart:typed_data';

import 'package:labels/backup.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/backup_inventory.dart';

typedef PreparedBackup = ({
  String digest,
  Future<Result<Uint8List, BackupMetadataFailure>> Function() encrypt,
});

/// The digest covers all canonical plaintext items, including descriptors.
abstract interface class BackupMetadataCodec {
  @useResult
  Result<PreparedBackup, BackupMetadataFailure> prepare(
    BackupGroup group,
    LabelsSnapshot snapshot,
  );

  /// A null value means that the envelope did not authenticate for this group.
  @useResult
  Future<Result<LabelsSnapshot?, BackupMetadataFailure>> decode(
    BackupGroup group,
    Uint8List envelope,
  );
}
