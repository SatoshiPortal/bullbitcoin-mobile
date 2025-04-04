import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';

class SendWithPayjoinUsecase {
  final PayjoinRepository _payjoinRepository;

  const SendWithPayjoinUsecase({required PayjoinRepository payjoinRepository})
      : _payjoinRepository = payjoinRepository;

  Future<Payjoin> execute({
    required String walletId,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
    int? expireAfterSec,
  }) {
    try {
      return _payjoinRepository.createPayjoinSender(
        walletId: walletId,
        bip21: bip21,
        originalPsbt: originalPsbt,
        networkFeesSatPerVb: networkFeesSatPerVb,
        expireAfterSec: expireAfterSec,
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
