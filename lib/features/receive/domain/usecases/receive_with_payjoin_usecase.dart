import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class ReceiveWithPayjoinUsecase {
  final PayjoinReceiver _receiver;

  const ReceiveWithPayjoinUsecase(this._receiver);

  @useResult
  Future<Result<PayjoinReceiverSession, ReceiveFailure>> execute({
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
    switch (result) {
      case Ok(:final value):
        return Ok(value);
      case Err(:final failure):
        log.warning(
          'Failed to start the payjoin receiver: ${failure.logMessage}',
        );
        return Err(ReceivePayjoinUnavailableFailure(failure.logMessage));
    }
  }
}
