import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

class ClearSpScanStateUsecase {
  final SpAccountRepository _repository;

  ClearSpScanStateUsecase({required this._repository});

  @useResult
  Future<Result<void, SpFailure>> execute() => _repository.clearScanState();
}
