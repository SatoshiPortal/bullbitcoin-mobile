import 'package:silent/src/domain/repositories/sp_auto_scan_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/silent_failure.dart';

/// Turns automatic scanning on or off. The repository owns the cached value the
/// sync path and the UI read, so this only writes.
class SetSpAutoScanUsecase {
  final SpAutoScanRepository _repository;

  SetSpAutoScanUsecase({required this._repository});

  Future<Result<void, SilentFailure>> execute({required bool isEnabled}) =>
      _repository.save(isEnabled: isEnabled);
}
