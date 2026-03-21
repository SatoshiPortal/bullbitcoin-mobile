import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';

class SubmitSignedCetsUsecase {
  SubmitSignedCetsUsecase({required DlcRepository dlcRepository})
      : _dlcRepository = dlcRepository;

  final DlcRepository _dlcRepository;

  /// [cetSignatureHex] must be produced by the key-signing logic before calling this.
  Future<DlcContract> execute({
    required String contractId,
    required String cetSignatureHex,
  }) =>
      _dlcRepository.submitSignedCets(
        contractId: contractId,
        cetSignatureHex: cetSignatureHex,
      );
}
