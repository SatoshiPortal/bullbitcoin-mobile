import 'package:bb_mobile/features/sp/domain/repositories/sp_auto_scan_repository.dart';

/// Whether the wallet may resume scanning on its own.
class GetSpAutoScanUsecase {
  final SpAutoScanRepository _repository;

  GetSpAutoScanUsecase({required this._repository});

  bool execute() => _repository.isEnabledNow;

  Future<bool> read() async {
    try {
      await _repository.warmUp();
      return execute();
    } on Exception catch (_) {
      return false;
    }
  }
}
