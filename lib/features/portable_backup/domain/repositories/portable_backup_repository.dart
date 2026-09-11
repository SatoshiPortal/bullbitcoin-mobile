import 'dart:typed_data';
import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class PortableBackupRepository {
  @useResult
  Future<Result<PortableBackupFiles, PortableBackupFailure>> prepare({
    required String words,
    required String metadataJson,
    required String descriptor,
    required String network,
  });
  @useResult
  Future<Result<String, PortableBackupFailure>> publish({
    required String words,
    required Uint8List encryptedFile,
    required Uri relay,
    required NostrSession session,
  });
  @useResult
  Future<Result<PortableBackupFetch, PortableBackupFailure>> fetch({
    required String words,
    required String network,
    required Uri relay,
    required NostrSession session,
  });
  @useResult
  Future<Result<PortableBackupArtifact, PortableBackupFailure>> open({
    required String words,
    required Uint8List file,
    required String network,
    required PortableBackupKind kind,
  });
  @useResult
  Future<Result<PortableBackupArtifact, PortableBackupFailure>> openEncoded({
    required String words,
    required String encodedFile,
    required String network,
    required PortableBackupKind kind,
  });

  @useResult
  Future<Result<String, PortableBackupFailure>> derivePassword(String rootXprv);
}
