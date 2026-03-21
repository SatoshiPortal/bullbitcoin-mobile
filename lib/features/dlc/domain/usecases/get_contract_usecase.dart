import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';

class GetContractUsecase {
  GetContractUsecase({required DlcRepository dlcRepository})
      : _dlcRepository = dlcRepository;

  final DlcRepository _dlcRepository;

  Future<DlcContract> execute({required String contractId}) =>
      _dlcRepository.getContract(contractId: contractId);
}
