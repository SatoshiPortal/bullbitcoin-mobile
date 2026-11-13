import 'package:bb_mobile/core/wallet/domain/wallet_mutation_guard.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Inspects setup state without opening an account or modifying files.
class CheckSpSetupEntryUsecase {
  const CheckSpSetupEntryUsecase({
    required this._configs,
    required this._files,
    required this._walletMutationGuard,
  });

  final SpBackendConfigRepository _configs;
  final SpAccountFilesPort _files;
  final WalletMutationGuard _walletMutationGuard;

  /// True for an existing verified account; false only for a fresh setup.
  /// A verified pending marker returns [SpRecoveryRequired] for explicit retry.
  @useResult
  Future<Result<bool, SpFailure>> execute() =>
      _walletMutationGuard.exclusive(_read);

  Future<Result<bool, SpFailure>> _read() async {
    try {
      switch (await _configs.hasLegacyConfig()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: true):
          return const Err(SpLegacySourceUnverified());
        case Ok():
          break;
      }
      switch (await _files.hasLegacyData()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: true):
          return const Err(SpLegacySourceUnverified());
        case Ok():
          break;
      }
      final SpBackendConfig? config;
      switch (await _configs.fetch()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          config = value;
      }
      if (config == null) {
        switch (await _files.accountDirExists()) {
          case Err(:final failure):
            return Err(failure);
          case Ok(value: true):
            return const Err(SpConfigInvalid('SP account has no binding'));
          case Ok():
            break;
        }
        switch (await _files.hasOrphanBackups()) {
          case Err(:final failure):
            return Err(failure);
          case Ok(value: true):
            return const Err(SpConfigInvalid('SP data needs inspection'));
          case Ok():
            return const Ok(false);
        }
      }
      if (config.source == null) return const Err(SpLegacySourceUnverified());
      switch (await _files.hasRevokedSentinel()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: true):
          return const Err(SpConfigInvalid('SP revoke is incomplete'));
        case Ok():
          break;
      }
      if (await _files.verifyResumeBackups(config) case Err()) {
        // A recovery error here does not prove a pending marker.
        return Err(SpConfigInvalid('SP backup state cannot be verified'));
      }
      if (await _files.verifyAccountIdentity(config) case Ok()) {
        return const Ok(true);
      }
      if (await _files.verifyPendingIdentity(config) case Ok()) {
        return const Err(SpRecoveryRequired());
      }
      return const Err(SpConfigInvalid('SP identity cannot be verified'));
    } on Exception catch (_) {
      return const Err(SpUnexpected('SP setup inspection failed'));
    }
  }
}
