import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/repositories/sp_backend_config_repository.dart';
import 'package:silent/src/domain/entities/sp_backend_config.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:meta/meta.dart';

/// Reads the stored SP backend config for the settings form, so the cubit
/// depends on a use case instead of the repository directly.
class LoadSpBackendConfigUsecase {
  final SpBackendConfigRepository _configRepository;

  LoadSpBackendConfigUsecase({required this._configRepository});

  @useResult
  Future<Result<SpBackendConfig?, SilentFailure>> execute() =>
      _configRepository.fetch();
}
