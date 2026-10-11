import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:meta/meta.dart';

class GetDataRecoverySecretUsecase {
  final NostrIdentityFacade _identities;
  const GetDataRecoverySecretUsecase(this._identities);

  @useResult
  Future<Result<Secret, BackupSettingsFailure>> execute({
    String? expectedFingerprint,
    bool forVault = false,
  }) async {
    if (forVault && expectedFingerprint == null) {
      return const Err(BackupSettingsWordsUnavailableFailure());
    }
    switch (await _identities.defaultSecret()) {
      case Err():
        return const Err(BackupSettingsWordsUnavailableFailure());
      case Ok(:final value):
        if (expectedFingerprint != null &&
            value.id.hex != expectedFingerprint.toLowerCase()) {
          return const Err(BackupSettingsWordsUnavailableFailure());
        }
        return Ok(value);
    }
  }
}
