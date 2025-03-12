import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_core/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/_core/domain/services/payjoin_watcher_service.dart';

class SendWithPayjoinUseCase {
  final PayjoinRepository _payjoinRepository;

  const SendWithPayjoinUseCase({required PayjoinRepository payjoinRepository})
      : _payjoinRepository = payjoinRepository;

  Future<Payjoin> execute({
    required String walletId,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
  }) {
    try {
      return _payjoinRepository.createPayjoinSender(
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
