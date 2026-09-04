import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class SendWithPayjoinUsecase {
  final PayjoinSender _sender;

  const SendWithPayjoinUsecase(this._sender);

  @useResult
  Future<Result<PayjoinSenderSession, PayFailure>> execute({
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
        expiresAt: expireAfterSec == null
            ? null
            : DateTime.now().add(Duration(seconds: expireAfterSec)),
      ),
    );

    switch (result) {
      case Ok(:final value):
        return Ok(value);
      case Err(:final failure):
        // Not necessarily a failed payment: the engine persists the session,
        // signed original included, before posting to the directory. The caller
        // checks for that row before treating this as a dead end.
        log.warning('Failed to start the Pay Payjoin session', error: failure);
        return Err(PayUnexpectedFailure('$failure'));
    }
  }
}
