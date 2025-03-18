import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_core/domain/repositories/payjoin_repository.dart';

class ReceiveWithPayjoinUsecase {
  final PayjoinRepository _payjoinRepository;

  const ReceiveWithPayjoinUsecase({
    required PayjoinRepository payjoinRepository,
  }) : _payjoinRepository = payjoinRepository;

  Future<PayjoinReceiver> execute({
    required String walletId,
    required String address,
    required bool isTestnet,
    int? expireAfterSec,
  }) {
    try {
      return _payjoinRepository.createPayjoinReceiver(
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
