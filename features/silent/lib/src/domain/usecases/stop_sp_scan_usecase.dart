import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/ports/sp_scan_control_port.dart';
import 'package:silent/src/domain/silent_failure.dart';

class StopSpScanUsecase {
  final SpScanControlPort _repository;

  StopSpScanUsecase({required this._repository});

  Future<Result<void, SilentFailure>> execute() => _repository.stopScan();
}
