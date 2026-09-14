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

  Future<Result<List<String>, BackupSettingsFailure>> execute() async =>
      switch (await _identity.revealBackupWords()) {
        Ok(:final value) => Ok(value.split(' ')),
        Err() => const Err(BackupSettingsBackupWordsUnavailableFailure()),
      };
}
