import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/ports/sp_scan_control_port.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:meta/meta.dart';

class ClearSpScanStateUsecase {
  final SpScanControlPort _repository;

  ClearSpScanStateUsecase({required this._repository});

  @useResult
  Future<Result<void, SilentFailure>> execute() => _repository.clearScanState();
}
