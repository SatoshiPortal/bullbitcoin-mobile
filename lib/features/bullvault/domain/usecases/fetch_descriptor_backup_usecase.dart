import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/descriptor_backup_repository.dart';
import 'package:meta/meta.dart';

final class FetchDescriptorBackupUsecase {
  final DescriptorBackupRepository _repository;
  const FetchDescriptorBackupUsecase(this._repository);
  @useResult
  Future<Result<DescriptorBackupFetch, BullVaultFailure>> execute({
    required String input,
    required Uri relay,
    required DescriptorBackupSession session,
  }) => _repository.fetch(input, relay, session);
}
