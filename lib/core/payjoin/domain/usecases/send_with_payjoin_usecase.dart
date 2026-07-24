import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';

class SendWithPayjoinUsecase {
  final PayjoinRepository _payjoinRepository;
  final BitcoinWalletRepository _bitcoinWalletRepository;
  final SettingsRepository _settingsRepository;

  const SendWithPayjoinUsecase({
    required this._payjoinRepository,
    required this._bitcoinWalletRepository,
    required this._settingsRepository,
  });

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

      // The user-configured session lifetime (payjoin settings screen)
      // unless the caller explicitly overrides it (e.g. tests) — resolved
      // here, not by the caller, to mirror ReceiveWithPayjoinUsecase so the
      // two sides can't silently drift apart.
      final settings = await _settingsRepository.fetch();

      final pjSender = await _payjoinRepository.createPayjoinSender(
        walletId: walletId,
        isTestnet: isTestnet,
        bip21: bip21,
        originalPsbt: signedOriginalPsbt,
        amountSat: amountSat,
        networkFeesSatPerVb: networkFeesSatPerVb,
        expireAfterSec: expireAfterSec ?? settings.payjoinExpireAfterSec,
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
