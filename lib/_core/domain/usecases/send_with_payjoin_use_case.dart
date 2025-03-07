import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_core/domain/services/payjoin_service.dart';

class SendWithPayjoinUseCase {
  final PayjoinService _payjoinService;

  const SendWithPayjoinUseCase({required PayjoinService payjoinService})
      : _payjoinService = payjoinService;

  Future<Payjoin> execute({
    required String walletId,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
  }) {
    try {
      return _payjoinService.createPayjoinSender(
        walletId: walletId,
        bip21: bip21,
        originalPsbt: originalPsbt,
        networkFeesSatPerVb: networkFeesSatPerVb,
      );
    } catch (e) {
      throw SendPayjoinException(e.toString());
    }
  }
}

class SendPayjoinException implements Exception {
  final String message;

  SendPayjoinException(this.message);
}
