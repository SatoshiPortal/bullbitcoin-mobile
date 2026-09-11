import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';
import 'package:bb_mobile/features/portable_backup/domain/repositories/portable_backup_repository.dart';
import 'package:meta/meta.dart';

/// Internal sealed credential UI only; never expose this through a facade.
final class DeriveBackupPasswordUsecase {
  final PortableBackupRepository _repository;
  const DeriveBackupPasswordUsecase(this._repository);
  @useResult
  Future<Result<String, PortableBackupFailure>> execute(String rootXprv) =>
      _repository.derivePassword(rootXprv);
}
