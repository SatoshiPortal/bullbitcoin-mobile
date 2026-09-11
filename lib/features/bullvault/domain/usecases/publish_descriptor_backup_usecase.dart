import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/descriptor_backup_repository.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:meta/meta.dart';

final class PublishDescriptorBackupUsecase {
  final DescriptorBackupRepository _repository;
  final NostrIdentityFacade _identity;
  const PublishDescriptorBackupUsecase(this._repository, this._identity);

  @useResult
  Future<Result<List<String>, BullVaultFailure>> execute({
    required String descriptor,
    required Uri relay,
    required DescriptorBackupSession session,
  }) async {
    final prepared = _repository.prepare(descriptor);
    if (prepared case Err(:final failure)) return Err(failure);
    final backup = (prepared as Ok<DescriptorBackup, BullVaultFailure>).value;
    final ids = <String>[];
    for (final recipient in backup.recipients) {
      if (session.isCancelled) return const Err(BullVaultBackupStatusFailure());
      final authorResult = await _identity.descriptorBackupPublicKey(
        recipient.lookup,
      );
      if (authorResult case Err()) {
        return const Err(BullVaultBackupStatusFailure());
      }
      final author = (authorResult as Ok<String, NostrIdentityFailure>).value;
      final request = _repository.signingRequest(
        recipient,
        author,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final signed = await _identity.signDescriptorBackupHash(
        lookup: recipient.lookup,
        hashHex: request.hash,
        expectedPublicKey: author,
      );
      if (signed case Err()) return const Err(BullVaultBackupStatusFailure());
      final result = await _repository.publish(
        request,
        (signed as Ok<String, NostrIdentityFailure>).value,
        relay,
        session,
      );
      switch (result) {
        case Ok(:final value):
          ids.add(value);
        case Err(:final failure):
          return Err(failure);
      }
    }
    return Ok(List.unmodifiable(ids));
  }
}
