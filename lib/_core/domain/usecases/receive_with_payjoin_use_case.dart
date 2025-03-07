import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_core/domain/services/payjoin_service.dart';

class ReceiveWithPayjoinUseCase {
  final PayjoinService _payjoinService;

  const ReceiveWithPayjoinUseCase({required PayjoinService payjoinService})
      : _payjoinService = payjoinService;

  Future<Payjoin> execute({
    required String walletId,
    required String address,
    required bool isTestnet,
    int? expireAfterSec,
  }) {
    try {
      return _payjoinService.createPayjoinReceiver(
        walletId: walletId,
        address: address,
        isTestnet: isTestnet,
        maxFeeRateSatPerVb: BigInt.from(10000),
        expireAfterSec: expireAfterSec,
      );
    } catch (e) {
      throw ReceivePayjoinException(e.toString());
    }
  }
}

class ReceivePayjoinException implements Exception {
  final String message;

  ReceivePayjoinException(this.message);
}
