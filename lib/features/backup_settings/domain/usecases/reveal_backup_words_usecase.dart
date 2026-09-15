import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

/// Derives the twelve magic backup words for the protected reveal screen.
///
/// The words are returned to the caller and kept nowhere: no cubit state, no
/// route argument, no log. A device without a default seed cannot derive them
/// at all, which is a different answer from a failure and has its own message.
final class RevealBackupWordsUsecase {
  final NostrIdentityFacade _identity;

  const RevealBackupWordsUsecase(this._identity);

  /// [originFingerprint] is the wallet a vault records as its own, and
  /// [forVault] says the reveal was asked for a vault rather than for this
  /// device's own Data Backup.
  ///
  /// A vault that records no origin at all is refused like a foreign one: the
  /// wallet that published its backups was never identified here, so this
  /// device's words are no more its credential than any other phone's.
  Future<Result<List<String>, BackupSettingsFailure>> execute({
    String? originFingerprint,
    bool forVault = false,
  }) async {
    if (forVault && originFingerprint == null) {
      return const Err(BackupSettingsForeignBackupWordsFailure());
    }
    return switch (await _identity.revealBackupWords(
      expectedOriginFingerprint: originFingerprint,
    )) {
      Ok(:final value) => Ok(value.split(' ')),
      Err(failure: NostrIdentityForeignCredentialFailure()) => const Err(
        BackupSettingsForeignBackupWordsFailure(),
      ),
      Err() => const Err(BackupSettingsBackupWordsUnavailableFailure()),
    };
  }
}
