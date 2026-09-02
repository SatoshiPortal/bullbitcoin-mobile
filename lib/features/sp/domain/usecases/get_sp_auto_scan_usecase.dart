import 'package:bb_mobile/features/sp/domain/repositories/sp_auto_scan_repository.dart';

/// Whether the wallet may resume scanning on its own. Synchronous: the sync
/// tick and the UI both read it on a path that cannot await.
class GetSpAutoScanUsecase {
  final SpAutoScanRepository _repository;

  GetSpAutoScanUsecase({required this._repository});

  bool execute() => _repository.isEnabledNow;
}
