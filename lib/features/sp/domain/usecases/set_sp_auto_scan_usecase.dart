import 'package:bb_mobile/features/sp/domain/repositories/sp_auto_scan_repository.dart';

/// Turns automatic scanning on or off. The repository owns the cached value the
/// sync path and the UI read, so this only writes.
class SetSpAutoScanUsecase {
  final SpAutoScanRepository _repository;

  SetSpAutoScanUsecase({required this._repository});

  Future<void> execute({required bool isEnabled}) =>
      _repository.save(isEnabled: isEnabled);
}
