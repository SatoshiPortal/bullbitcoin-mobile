import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';

class DetectBitcoinStringUsecase {
  DetectBitcoinStringUsecase();

  Future<PaymentRequest> execute({required String data}) async {
    try {
      return await PaymentRequest.parse(data);
    } catch (e) {
      log.warning('Invalid payment request', error: e);
      rethrow;
    }
  }
}
