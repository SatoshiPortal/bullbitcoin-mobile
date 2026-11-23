import 'package:bb_mobile/features/transactions/public/prepare_payjoin_original.dart';
import 'package:spend/spend.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class SendWithPayjoinUsecase {
  final PayjoinSender _sender;

  final Spend _spend;

  const SendWithPayjoinUsecase(this._sender, this._spend);

  @useResult
  Future<Result<PayjoinSenderSession, PayFailure>> execute({
    required String walletId,
    required BitcoinNetwork network,
    required String bip21,
    required PreparedBitcoinSpend prepared,
    required int amountSat,
    required double networkFeesSatPerVb,
    int? expireAfterSec,
  }) async {
    if (!NetworkCapabilities.supports(network, NetworkCapability.payjoin)) {
      return const Err(PayUnexpectedFailure('unsupported network'));
    }
    final PreparedPayjoinOriginal original;
    switch (await preparePayjoinOriginal(
      spend: _spend,
      prepared: prepared,
      walletId: walletId,
      network: network,
    )) {
      case Ok(:final value):
        original = value;
      case Err(failure: SpendUnavailableFailure(:final busy)):
        return Err(PaySpendBlockedFailure(busy: busy));
      case Err():
        return const Err(PayUnexpectedFailure());
    }
    final result = await _sender.start(
      StartPayjoinSender(
        walletId: walletId,
        network: network,
        bip21Uri: bip21,
        unsignedOriginalPsbt: prepared.unsignedPsbt,
        preparedOriginal: original,
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
      case Err(failure: PayjoinSpendBlockedFailure(:final busy)):
        return Err(PaySpendBlockedFailure(busy: busy));
      case Err(failure: PayjoinPublicationUnknownFailure(:final originalTxId)):
        return Err(PayPayinOutcomeUnknownFailure(originalTxId: originalTxId));
      case Err(failure: PayjoinSenderKeptFailure(:final logMessage)):
        log.warning(
          'Pay Payjoin post failed; the session is kept',
          error: logMessage ?? '-',
        );
        return Err(PayPayjoinSessionKeptFailure(logMessage));
      case Err(:final failure):
        // Not necessarily a failed payment: the engine persists the session,
        // signed original included, before posting to the directory. The caller
        // checks for that row before treating this as a dead end.
        log.warning('Failed to start the Pay Payjoin session', error: failure);
        return Err(PayUnexpectedFailure('$failure'));
    }
  }
}
