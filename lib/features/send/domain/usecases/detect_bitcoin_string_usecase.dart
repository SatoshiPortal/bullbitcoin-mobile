import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:flutter/foundation.dart';

class DetectBitcoinStringUsecase {
  DetectBitcoinStringUsecase();

  Future<PaymentRequest> execute({required String data}) async {
    try {
      return await PaymentRequest.parse(data);
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }
}
