import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';

class CheckSpWalletSetupUsecase {
  final SpBackendConfigRepository _configRepository;
  final SpAccountRepository _accountRepository;

  CheckSpWalletSetupUsecase({
    required this._configRepository,
    required this._accountRepository,
  });

  /// The SP wallet is set up when a backend config is stored and no `.revoked`
  /// sentinel is present. Only those two "not configured" signals return false;
  /// unexpected errors propagate. Keep in sync with `EnsureSpSessionUsecase`.
  Future<bool> execute() async {
    final config = (await _configRepository.fetch()).fold(
      (config) => config,
      (_) => null,
    );
    if (config == null) return false;

    if (await _accountRepository.hasRevokedSentinel()) return false;

    return true;
  }
}
