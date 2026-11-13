import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:primitives/primitives.dart';

/// Checks persisted SP ownership without acquiring the SP session guard.
class CheckSpSourceRetentionUsecase {
  const CheckSpSourceRetentionUsecase(this._configRepository, this._files);
  final SpBackendConfigRepository _configRepository;
  final SpAccountFilesPort _files;

  Future<Result<bool, SpFailure>> execute({
    String? walletId,
    Fingerprint? secretId,
  }) async {
    if (walletId == null && secretId == null) {
      return const Err(SpConfigInvalid('SP retention query is empty'));
    }
    switch (await _configRepository.hasLegacyConfig()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: true):
        return const Ok(true);
      case Ok():
        break;
    }
    switch (await _files.hasLegacyData()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: true):
        return const Ok(true);
      case Ok():
        break;
    }
    switch (await _configRepository.fetch()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: null):
        // Orphaned account data may be the only evidence of an old source.
        switch (await _files.accountDirExists()) {
          case Err(:final failure):
            return Err(failure);
          case Ok(value: true):
            return const Ok(true);
          case Ok():
            break;
        }
        switch (await _files.hasOrphanBackups()) {
          case Err(:final failure):
            return Err(failure);
          case Ok(:final value):
            return Ok(value);
        }
      case Ok(value: final config?):
        final source = config.source;
        // Legacy identity is unknown, so no wallet or seed can be proved unused.
        if (source == null) return const Ok(true);
        final sourceId = Fingerprint.tryParse(source.secretId);
        if (sourceId == null) {
          return const Err(SpConfigInvalid('Invalid SP source'));
        }
        if ((walletId != null && source.walletId == walletId) ||
            (secretId != null && sourceId == secretId)) {
          return const Ok(true);
        }
        // A false answer requires independent proof: the config may be
        // corrupted to name a different syntactically valid source.
        if (await _files.verifyAccountIdentity(config) case Err(
          :final failure,
        )) {
          return Err(failure);
        }
        switch (await _files.hasOrphanBackups()) {
          case Err(:final failure):
            return Err(failure);
          case Ok(value: true):
            return const Ok(true);
          case Ok():
            return const Ok(false);
        }
    }
  }
}
