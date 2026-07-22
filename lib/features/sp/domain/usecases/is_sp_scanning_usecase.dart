import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';

/// Whether a scan is running, tracked in Dart from notifications (no FFI). The
/// facade exposes this through a use-case seam so cross-feature callers (the
/// wallet) can skip their refresh while a scan holds the inner lock.
class IsSpScanningUsecase {
  final SpAccountRepository _repository;

  IsSpScanningUsecase({required this._repository});

  bool execute() => _repository.isScanningCached;
}
