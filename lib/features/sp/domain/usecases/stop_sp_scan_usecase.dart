import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';

class StopSpScanUsecase {
  final SpAccountRepository _repository;

  StopSpScanUsecase({required this._repository});

  Future<void> execute() => _repository.stopScan();
}
