import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/decode_invoice_usecase.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:flutter/foundation.dart';

class DetectBitcoinStringUsecase {
  final SwapRepository _mainnetSwapRepository;
  final SwapRepository _testnetSwapRepository;

  DetectBitcoinStringUsecase({
    required SwapRepository mainnetSwapRepository,
    required SwapRepository testnetSwapRepository,
  }) : _mainnetSwapRepository = mainnetSwapRepository,
       _testnetSwapRepository = testnetSwapRepository;

  Future<PaymentRequest> execute({required String data}) async {
    try {
      final paymentRequest = await PaymentRequest.parse(data);
      if (paymentRequest.isBolt11) {
        final decodeInvoiceUsecase = DecodeInvoiceUsecase(
          mainnetSwapRepository: _mainnetSwapRepository,
          testnetSwapRepository: _testnetSwapRepository,
        );
        final invoice = await decodeInvoiceUsecase.execute(
          invoice: (paymentRequest as Bolt11PaymentRequest).invoice,
          isTestnet: paymentRequest.isTestnet,
        );
        if (invoice.magicBip21 != null) {
          // use the liquid bip21 decoder
          return await PaymentRequest.parse(invoice.magicBip21!);
        }
      }
      return await PaymentRequest.parse(data);
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }
}
