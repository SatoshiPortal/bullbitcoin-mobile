import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';
import 'package:bb_mobile/features/portable_backup/domain/repositories/portable_backup_repository.dart';
import 'package:meta/meta.dart';

final class OpenPortableBackupUsecase {
  final PortableBackupRepository _repository;
  const OpenPortableBackupUsecase(this._repository);

  @useResult
  Future<Result<PortableBackupArtifact, PortableBackupFailure>> execute({
    required String words,
    required String encodedFile,
    required String network,
    required PortableBackupKind kind,
  }) => _repository.openEncoded(
    words: words,
    encodedFile: encodedFile,
    network: network,
    kind: kind,
  );
}
