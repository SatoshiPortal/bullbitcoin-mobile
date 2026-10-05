import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_scan_control_port.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

class ClearSpScanStateUsecase {
  final SpScanControlPort _repository;

  ClearSpScanStateUsecase({required this._repository});

  @useResult
  Future<Result<void, SpFailure>> execute() => _repository.clearScanState();
}
