import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Builds the backup credential of the wallet this app calls its own.
///
/// The credential is rebuilt at every call and never cached: it carries the
/// twelve words, and a long-lived copy is a long-lived secret.
class BackupCredentialResolver {
  final GetSettingsUsecase _settings;
  final GetDefaultSeedUsecase _defaultSeed;

  const BackupCredentialResolver(this._settings, this._defaultSeed);

  @useResult
  Future<Result<BackupCredential, NostrIdentityFailure>> resolve() async {
    switch (await _seed()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return Ok(BackupCredential.fromSeed(value));
    }
  }

  /// The twelve words themselves, derived at the point of use for a protected
  /// reveal. Nothing else in the feature hands them out.
  @useResult
  Future<Result<String, NostrIdentityFailure>> revealWords() async {
    switch (await _seed()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return Ok(BackupCredential.deriveWords(value));
    }
  }

  Future<Result<Seed, NostrIdentityFailure>> _seed() async {
    final SettingsEntity settings;
    try {
      settings = await _settings.execute();
    } on Exception catch (error, trace) {
      log.warning(
        'Backup credential wallet lookup failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(NostrIdentityUnavailableFailure());
    }

    switch (await _defaultSeed.execute(environment: settings.environment)) {
      case Ok(:final value):
        return Ok(value);
      case Err(:final failure):
        log.warning(
          'Backup credential seed is unavailable',
          error: failure.runtimeType,
        );
        return const Err(NostrIdentityUnavailableFailure());
    }
  }
}
