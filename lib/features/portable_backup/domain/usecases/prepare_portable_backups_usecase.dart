import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/portable_backup/domain/repositories/portable_backup_repository.dart';

final class PreparePortableBackupsUsecase {
  final PortableBackupRepository _repository;
  const PreparePortableBackupsUsecase(this._repository);
  @useResult
  Future<Result<PortableBackupFiles, PortableBackupFailure>> execute({
    required String words,
    required String metadataJson,
    required String descriptor,
    required String network,
  }) => _repository.prepare(
    words: words,
    metadataJson: metadataJson,
    descriptor: descriptor,
    network: network,
  );
}
