import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

class ReceiveWithPayjoinUsecase {
  final PayjoinReceiver _receiver;

  const ReceiveWithPayjoinUsecase(this._receiver);

  Future<PayjoinReceiverSession> execute({
    required String walletId,
    bool isTestnet = false,
    required String address,
    int? expireAfterSec,
    int? amountSat,
  }) async {
    final result = await _receiver.start(
      StartPayjoinReceiver(
        walletId: walletId,
        network: isTestnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet,
        address: address,
        amount: amountSat == null ? null : Sats.fromInt(amountSat),
        expiresAt: expireAfterSec == null
            ? null
            : DateTime.now().add(Duration(seconds: expireAfterSec)),
      ),
    );
    return switch (result) {
      Ok(:final value) => value,
      Err() => throw ReceivePayjoinException(
        'Failed to start Payjoin receiver',
      ),
    };
  }
}

class ReceivePayjoinException extends BullException {
  ReceivePayjoinException(super.message);
}
