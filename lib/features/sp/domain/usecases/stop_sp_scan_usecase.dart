import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_scan_control_port.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';

class StopSpScanUsecase {
  final SpScanControlPort _repository;

  StopSpScanUsecase({required this._repository});

  Future<Result<void, SpFailure>> execute() => _repository.stopScan();
}
