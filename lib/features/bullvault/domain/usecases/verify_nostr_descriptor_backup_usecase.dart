import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_parser.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/discover_descriptors_on_nostr_usecase.dart';
import 'package:meta/meta.dart';

/// What a read-back proved about one vault.
///
/// [found] is the only thing that may advance a test date: the relays returned
/// an event, it decrypted, and the descriptor inside is this vault's. [incomplete]
/// says a search that found nothing cannot be reported as an absence.
typedef NostrDescriptorVerification = ({bool found, bool incomplete});

/// Proves a vault is recoverable from the relays, by recovering it.
final class VerifyNostrDescriptorBackupUsecase {
  final BullVaultRepository _repository;
  final DiscoverDescriptorsOnNostrUsecase _discover;

  const VerifyNostrDescriptorBackupUsecase(this._repository, this._discover);

  @useResult
  Future<Result<NostrDescriptorVerification, BullVaultFailure>> execute(
    String walletId, {
    NostrSession? session,
  }) async {
    final BullVaultRecord record;
    switch (await _repository.getByWalletId(walletId)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final stored?):
        record = stored;
      case Ok():
        return const Err(BullVaultInvalidRecoveryFailure());
    }
    final policy = record.recoveryPackage.policy;
    final String canonical;
    try {
      canonical = DescriptorBackupParser.parseDescriptor(
        policy.descriptor,
      ).descriptor;
    } on FormatException {
      return const Err(BullVaultInvalidRecoveryFailure());
    }
    switch (await _discover.execute(session: session)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return Ok((
          found: value.descriptors.any(
            (found) =>
                found.network == policy.network &&
                found.descriptor == canonical,
          ),
          incomplete: value.incomplete,
        ));
    }
  }
}
