import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/backup_content.dart';
import '../entities/backup_inventory.dart';

typedef PreparedBackup = ({
  String digest,
  Future<Result<Uint8List, BackupMetadataFailure>> Function() encrypt,
});

/// The digest covers all canonical plaintext items, including descriptors.
/// An implementation writes a closed list of fields and, on decode, accepts
/// nothing it did not write.
abstract interface class BackupMetadataCodec {
  @useResult
  Result<PreparedBackup, BackupMetadataFailure> prepare(
    BackupGroup group,
    BackupContent content,
  );

  /// A null value means that the envelope did not authenticate for this group.
  @useResult
  Future<Result<BackupContent?, BackupMetadataFailure>> decode(
    BackupGroup group,
    Uint8List envelope,
  );
}
