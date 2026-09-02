import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';

/// Synchronous view of "the SP wallet is set up", for the route gate that
/// cannot await. `CheckSpWalletSetupUsecase` stays the authority; the config
/// repository caches its last answer.
class IsSpSetUpNowUsecase {
  final SpBackendConfigRepository _repository;

  IsSpSetUpNowUsecase({required this._repository});

  bool execute() => _repository.isSetUpNow;
}
