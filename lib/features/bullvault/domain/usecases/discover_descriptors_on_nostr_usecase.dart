import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/data/nostr_descriptor_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/nostr_descriptor_backup.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:meta/meta.dart';

/// Finds the vault descriptors one set of backup words published.
///
/// Nothing is imported here: the caller decides what to do with a validated
/// descriptor and imports it through the existing restore path, so discovery
/// can run on a device that owns no seed at all.
final class DiscoverDescriptorsOnNostrUsecase {
  final NostrIdentityFacade _identity;
  final NostrDescriptorRepository _nostr;

  const DiscoverDescriptorsOnNostrUsecase(this._identity, this._nostr);

  /// Searches with [words] when they are given, and with this wallet's own
  /// credential when they are not.
  ///
  /// Words are what an heir has, so the words path never reaches a seed, a
  /// fingerprint or the local database.
  @useResult
  Future<Result<NostrDescriptorSearch, BullVaultFailure>> execute({
    String? words,
    NostrSession? session,
  }) async {
    final BackupCredential credential;
    if (words != null) {
      try {
        credential = BackupCredential.fromWords(words);
      } on InvalidBackupWordsException {
        return const Err(BullVaultBackupWordsFailure());
      }
    } else {
      switch (await _identity.backupCredential()) {
        case Err():
          return const Err(BullVaultBackupCredentialFailure());
        case Ok(:final value):
          credential = value;
      }
    }
    return Ok(
      await _nostr.discover(
        credential: credential,
        session: session ?? NostrSession(),
      ),
    );
  }
}
