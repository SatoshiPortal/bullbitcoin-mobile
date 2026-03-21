import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';

class AcceptOfferUsecase {
  AcceptOfferUsecase({required DlcRepository dlcRepository})
      : _dlcRepository = dlcRepository;

  final DlcRepository _dlcRepository;

  /// [acceptHex] must be produced by the key-signing logic before calling this.
  Future<DlcContract> execute({
    required String offerId,
    required String acceptHex,
  }) =>
      _dlcRepository.acceptOffer(offerId: offerId, acceptHex: acceptHex);
}
