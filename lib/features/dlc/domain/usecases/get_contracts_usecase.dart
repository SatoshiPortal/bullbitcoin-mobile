import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';

class GetContractsUsecase {
  GetContractsUsecase({required DlcRepository dlcRepository})
      : _dlcRepository = dlcRepository;

  final DlcRepository _dlcRepository;

  Future<List<DlcContract>> execute() => _dlcRepository.getMyDlcs();
}
