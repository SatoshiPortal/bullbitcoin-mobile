import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:meta/meta.dart';

abstract interface class DescriptorBackupRepository {
  @useResult
  Result<DescriptorBackup, BullVaultFailure> prepare(String descriptor);
  DescriptorBackupPublication signingRequest(
    DescriptorBackupRecipient recipient,
    String author,
    int createdAt,
  );
  @useResult
  Future<Result<String, BullVaultFailure>> publish(
    DescriptorBackupPublication publication,
    String signature,
    Uri relay,
    DescriptorBackupSession session,
  );
  @useResult
  Future<Result<DescriptorBackupFetch, BullVaultFailure>> fetch(
    String input,
    Uri relay,
    DescriptorBackupSession session,
  );
}
