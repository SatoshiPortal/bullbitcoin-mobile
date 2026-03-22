import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';

/// Maker sign flow: fetches sign context and submits signatures.
class SignDlcUsecase {
  SignDlcUsecase({required DlcRepository dlcRepository})
      : _dlcRepository = dlcRepository;

  final DlcRepository _dlcRepository;

  /// Step 1: Get signing context for the maker.
  Future<Map<String, dynamic>> getContext({required String dlcId}) =>
      _dlcRepository.getSignContext(dlcId: dlcId);

  /// Step 2: Submit maker signatures to finalize the DLC.
  Future<DlcContract> submitSignatures({
    required String dlcId,
    required String cetAdaptorSignaturesHex,
    required String refundSignatureHex,
    required String fundingSignaturesHex,
  }) =>
      _dlcRepository.submitSign(
        dlcId: dlcId,
        cetAdaptorSignaturesHex: cetAdaptorSignaturesHex,
        refundSignatureHex: refundSignatureHex,
        fundingSignaturesHex: fundingSignaturesHex,
      );
}
