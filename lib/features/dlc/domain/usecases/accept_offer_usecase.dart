import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';

/// Taker accept-context step: fetches signing context for accepting an order.
class AcceptOfferUsecase {
  AcceptOfferUsecase({required DlcRepository dlcRepository})
      : _dlcRepository = dlcRepository;

  final DlcRepository _dlcRepository;

  Future<Map<String, dynamic>> execute({
    required String orderId,
    required String fundingPubkeyHex,
  }) =>
      _dlcRepository.getAcceptContext(
        orderId: orderId,
        fundingPubkeyHex: fundingPubkeyHex,
      );
}
