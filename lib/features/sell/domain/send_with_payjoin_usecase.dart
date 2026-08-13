import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

class SendWithPayjoinUsecase {
  final PayjoinSender _sender;

  const SendWithPayjoinUsecase(this._sender);

  Future<PayjoinSenderSession> execute({
    required String walletId,
    required bool isTestnet,
    required String bip21,
    required String unsignedOriginalPsbt,
    required int amountSat,
    required double networkFeesSatPerVb,
    int? expireAfterSec,
  }) async {
    final result = await _sender.start(
      StartPayjoinSender(
        walletId: walletId,
        network: isTestnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet,
        bip21Uri: bip21,
        unsignedOriginalPsbt: unsignedOriginalPsbt,
        amount: Sats.fromInt(amountSat),
        feeRate: FeeRate(networkFeesSatPerVb),
        isExchange: true,
        expiresAt: expireAfterSec == null
            ? null
            : DateTime.now().add(Duration(seconds: expireAfterSec)),
      ),
    );
    return switch (result) {
      Ok(:final value) => value,
      Err() => throw SendPayjoinException('Failed to start Payjoin sale'),
    };
  }
}

class SendPayjoinException extends BullException {
  SendPayjoinException(super.message);
}
