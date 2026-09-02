import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// Reads the stored SP backend config for the settings form, so the cubit
/// depends on a use case instead of the repository directly.
class LoadSpBackendConfigUsecase {
  final SpBackendConfigRepository _configRepository;

  LoadSpBackendConfigUsecase({required this._configRepository});

  @useResult
  Future<Result<SpBackendConfig?, SpFailure>> execute() =>
      _configRepository.fetch();
}
