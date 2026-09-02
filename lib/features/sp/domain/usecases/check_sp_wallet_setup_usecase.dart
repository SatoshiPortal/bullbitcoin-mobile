import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';

class CheckSpWalletSetupUsecase {
  final SpBackendConfigRepository _configRepository;
  final SpAccountFilesPort _files;

  CheckSpWalletSetupUsecase({
    required this._configRepository,
    required this._files,
  });

  /// The SP wallet is set up when a backend config is stored and no `.revoked`
  /// sentinel is present. Only those two "not configured" signals read as
  /// false; a failed config or sentinel read is `Err`, never a silent
  /// "not set up".
  /// Keep in sync with `EnsureSpSessionUsecase`.
  Future<Result<bool, SpFailure>> execute() async {
    final result = await _read();
    if (result case Ok(:final value)) {
      _configRepository.setIsSetUpNow(isSetUp: value);
    }
    return result;
  }

  Future<Result<bool, SpFailure>> _read() async {
    switch (await _configRepository.fetchOrNull()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: null):
        return const Ok(false);
      case Ok():
        break;
    }

    return switch (await _files.hasRevokedSentinel()) {
      Ok(value: true) => const Ok(false),
      Ok() => const Ok(true),
      Err(:final failure) => Err(failure),
    };
  }
}
