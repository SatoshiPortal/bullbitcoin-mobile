import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';

class DetectBitcoinStringUsecase {
  DetectBitcoinStringUsecase();

  Future<PaymentRequest> execute({required String data}) async {
    try {
      return await PaymentRequest.parse(data);
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      rethrow;
    }
  }
}
