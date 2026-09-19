import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:meta/meta.dart';

/// Only the sealed words screen consumes this operation-scoped value.
final class RevealedDataRecoveryWords {
  final String words;
  const RevealedDataRecoveryWords(this.words);

  @override
  String toString() => 'RevealedDataRecoveryWords(<redacted>)';
}

class RevealDataRecoveryWordsUsecase {
  final GetSettingsUsecase _settings;
  final GetDefaultSeedUsecase _seed;

  const RevealDataRecoveryWordsUsecase(this._settings, this._seed);

  @useResult
  Future<Result<RevealedDataRecoveryWords, BackupSettingsFailure>> execute({
    String? expectedFingerprint,
    bool forVault = false,
  }) async {
    if (forVault && expectedFingerprint == null) {
      return const Err(BackupSettingsWordsUnavailableFailure());
    }
    // These shared legacy use cases throw; map at this feature's boundary.
    try {
      final settings = await _settings.execute();
      final seed = await _seed.execute(environment: settings.environment);
      if (expectedFingerprint != null &&
          seed.masterFingerprint.toLowerCase() !=
              expectedFingerprint.toLowerCase()) {
        return const Err(BackupSettingsWordsUnavailableFailure());
      }
      return Ok(RevealedDataRecoveryWords(BackupCredential.deriveWords(seed)));
    } on Exception {
      return const Err(BackupSettingsWordsUnavailableFailure());
    }
  }
}
