import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core_deprecated/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core_deprecated/utils/constants.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/repositories/bitcoin_wallet_repository.dart';

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
    required bool isTestnet,
    required String bip21,
    required String unsignedOriginalPsbt,
    required int amountSat,
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
        isTestnet: isTestnet,
        bip21: bip21,
        originalPsbt: signedOriginalPsbt,
        amountSat: amountSat,
        networkFeesSatPerVb: networkFeesSatPerVb,
        expireAfterSec:
            expireAfterSec ?? PayjoinConstants.defaultExpireAfterSec,
      );

      return pjSender;
    } catch (e) {
      throw SendPayjoinException(e.toString());
    }
  }
}

class SendPayjoinException extends BullException {
  SendPayjoinException(super.message);
}
