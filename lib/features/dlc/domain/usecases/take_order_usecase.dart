import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';

/// Taker accept-match step: submits signed CETs to accept an order.
/// The signing stubs (cet_adaptor_signatures_hex, refund_signature_hex) must
/// be produced by the wallet key integration before calling this.
class TakeOrderUsecase {
  TakeOrderUsecase({required DlcRepository dlcRepository})
      : _dlcRepository = dlcRepository;

  final DlcRepository _dlcRepository;

  /// Step 1: Get signing context (returns raw map for now).
  Future<Map<String, dynamic>> getContext({
    required String orderId,
    required String fundingPubkeyHex,
  }) =>
      _dlcRepository.getAcceptContext(
        orderId: orderId,
        fundingPubkeyHex: fundingPubkeyHex,
      );

  /// Step 2: Submit signatures after signing locally.
  Future<Map<String, dynamic>> submitSignatures({
    required String orderId,
    required String fundingPubkeyHex,
    required String cetAdaptorSignaturesHex,
    required String refundSignatureHex,
  }) =>
      _dlcRepository.submitAcceptMatch(
        orderId: orderId,
        fundingPubkeyHex: fundingPubkeyHex,
        cetAdaptorSignaturesHex: cetAdaptorSignaturesHex,
        refundSignatureHex: refundSignatureHex,
      );
}
