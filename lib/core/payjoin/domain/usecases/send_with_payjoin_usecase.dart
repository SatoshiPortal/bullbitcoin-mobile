import 'package:bb_mobile/core/payjoin/data/repository/payjoin_repository_impl.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_wallet_repository.dart';

class SendWithPayjoinUsecase {
  final PayjoinRepository _payjoinRepository;
  final BitcoinWalletRepository _bitcoinWalletRepository;

  const SendWithPayjoinUsecase({
    required PayjoinRepository payjoinRepository,
    required BitcoinWalletRepository bitcoinWalletRepository,
  }) : _payjoinRepository = payjoinRepository,
       _bitcoinWalletRepository = bitcoinWalletRepository;

  Future<PayjoinSender> execute({
    required String walletId,
    required String bip21,
    required String unsignedOriginalPsbt,
    required double networkFeesSatPerVb,
    int? expireAfterSec,
  }) async {
    try {
      final signedOriginalPsbt = await _bitcoinWalletRepository.signPsbt(
        unsignedOriginalPsbt,
        walletId: walletId,
      );

      final pjSender = await _payjoinRepository.createPayjoinSender(
        walletId: walletId,
        bip21: bip21,
        originalPsbt: signedOriginalPsbt,
        networkFeesSatPerVb: networkFeesSatPerVb,
        expireAfterSec: expireAfterSec,
      );

      return pjSender;
    } catch (e) {
      throw SendPayjoinException(e.toString());
    }
  }
}

class SendPayjoinException implements Exception {
  final String message;

  SendPayjoinException(this.message);
}
