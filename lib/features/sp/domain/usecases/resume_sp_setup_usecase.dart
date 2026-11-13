import 'package:bb_mobile/core/wallet/domain/wallet_mutation_guard.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_secret_usecase.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show Secret;

/// Explicitly resumes one incomplete V2 setup, without changing its identity.
class ResumeSpSetupUsecase {
  const ResumeSpSetupUsecase({
    required this._repository,
    required this._files,
    required this._configs,
    required this._secrets,
    required this._guard,
    required this._walletMutationGuard,
  });

  final SpAccountRepository _repository;
  final SpAccountFilesPort _files;
  final SpBackendConfigRepository _configs;
  final GetSpSecretUsecase _secrets;
  final SpSessionGuard _guard;
  final WalletMutationGuard _walletMutationGuard;

  @useResult
  Future<Result<void, SpFailure>> execute() =>
      _guard.exclusive(() => _walletMutationGuard.exclusive(_resume));

  Future<Result<void, SpFailure>> _resume() async {
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
      final SpBackendConfig config;
      switch (await _configs.fetch()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: null):
          return const Err(SpRecoveryRequired());
        case Ok(value: final value?):
          config = value;
      }
      final source = config.source;
      if (source == null) return const Err(SpRecoveryRequired());
      switch (await _files.hasRevokedSentinel()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: true):
          return const Err(SpRecoveryRequired());
        case Ok():
          break;
      }
      if (await _files.verifyResumeBackups(config) case Err(:final failure)) {
        return Err(failure);
      }
      if (await _files.verifyPendingIdentity(config) case Err(:final failure)) {
        return Err(failure);
      }
      final resolved = await _secrets.resolve(
        config.network,
        walletId: source.walletId,
        expected: source,
      );
      final ({Secret secret, SpSourceBinding binding}) value;
      switch (resolved) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: final found):
          value = found;
      }
      _repository.beginTeardown();
      try {
        if (_repository.hasSession) {
          if (await _repository.dispose() case Err(:final failure)) {
            return Err(failure);
          }
        }
        final opened = await _walletMutationGuard.withoutReentrance(
          () => _repository.createFromSecret(
            network: config.network,
            expectedConfig: config,
            secret: value.secret,
            blindbitUrl: config.blindbitUrl,
            electrumUrl: config.electrumUrl,
            fetchConcurrencyFactor: config.fetchConcurrencyFactor,
            matchConcurrencyFactor: config.matchConcurrencyFactor,
          ),
        );
        if (opened case Err(:final failure)) {
          return failure is SpSourceMismatch
              ? Err(failure)
              : const Err(SpRecoveryRequired());
        }
        _configs.setIsSetUpNow(isSetUp: true);
        return const Ok(null);
      } finally {
        _repository.endTeardown();
      }
    } on Exception catch (_) {
      return const Err(SpUnexpected('SP setup resume failed'));
    }
  }
}
