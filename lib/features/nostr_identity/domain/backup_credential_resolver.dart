import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
import 'package:meta/meta.dart';

final class BackupCredentialResolver {
  final GetDefaultSeedUsecase _getDefaultSeed;
  final GetSettingsUsecase _getSettings;

  const BackupCredentialResolver({
    required this._getDefaultSeed,
    required this._getSettings,
  });

  @useResult
  Future<Result<BackupCredential, NostrIdentityFailure>> resolve() async {
    try {
      final settings = await _getSettings.execute();
      final seed = await _getDefaultSeed.execute(
        environment: settings.environment,
      );
      return Ok(BackupCredential.fromSeed(seed));
    } on Exception {
      return const Err(BackupCredentialUnavailable());
    }
  }

  @useResult
  Result<BackupCredential, NostrIdentityFailure> fromWords(String input) {
    try {
      return Ok(BackupCredential.fromWords(input));
    } on Exception {
      return const Err(InvalidDataRecoveryWords());
    }
  }
}
