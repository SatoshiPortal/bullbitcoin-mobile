import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';

class CancelDlcOrderUsecase {
  CancelDlcOrderUsecase({required DlcRepository dlcRepository})
      : _dlcRepository = dlcRepository;

  final DlcRepository _dlcRepository;

  Future<void> execute({
    required String orderId,
    required String makerPubkey,
    required String signatureHex,
  }) =>
      _dlcRepository.cancelOrder(
        orderId: orderId,
        makerPubkey: makerPubkey,
        signatureHex: signatureHex,
      );
}
