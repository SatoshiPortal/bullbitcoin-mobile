import 'dart:typed_data';
import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/portable_backup/domain/repositories/portable_backup_repository.dart';

final class PublishPortableVaultUsecase {
  final PortableBackupRepository _repository;
  const PublishPortableVaultUsecase(this._repository);
  @useResult
  Future<Result<String, PortableBackupFailure>> execute({
    required String words,
    required Uint8List encryptedFile,
    required Uri relay,
    required NostrSession session,
  }) => _repository.publish(
    words: words,
    encryptedFile: encryptedFile,
    relay: relay,
    session: session,
  );
}
