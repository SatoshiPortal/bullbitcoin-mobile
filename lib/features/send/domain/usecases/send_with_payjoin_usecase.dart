import 'package:spend/payjoin.dart';
import 'package:spend/spend.dart';
import 'package:primitives/primitives.dart' as core;
import 'package:send/send.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class SendWithPayjoinUsecase {
  final PayjoinSender _sender;

  final Spend _spend;

  const SendWithPayjoinUsecase(this._sender, this._spend);

  @useResult
  Future<core.Result<PayjoinSenderSession, SendFailure>> execute({
    required String walletId,
    required BitcoinNetwork network,
    required String bip21,
    required PreparedBitcoinSpend prepared,
    required int amountSat,
    required double networkFeesSatPerVb,
    int? expireAfterSec,
  }) async {
    if (!NetworkCapabilities.supports(network, NetworkCapability.payjoin)) {
      return const core.Err(
        SendTransactionConfirmationFailure(logMessage: 'unsupported network'),
      );
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
        return Err(SendSpendBlockedFailure(busy: busy));
      case Err():
        return const Err(SendTransactionConfirmationFailure());
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
        return core.Ok(value);
      case Err(failure: PayjoinUnavailableFailure(:final logMessage)):
        return core.Err(SendPayjoinUnavailableFailure(logMessage));
      case Err(failure: PayjoinSpendBlockedFailure(:final busy)):
        return core.Err(SendSpendBlockedFailure(busy: busy));
      case Err(failure: PayjoinPublicationUnknownFailure(:final originalTxId)):
        return core.Err(
          SendTransactionConfirmationFailure(
            keptPayjoinOriginalTxId: originalTxId,
            payjoinPublicationUnknown: true,
          ),
        );
      case Err(
        failure: PayjoinSenderKeptFailure(
          :final originalTxId,
          :final logMessage,
        ),
      ):
        log.warning(
          'Payjoin send post failed; the session is kept',
          error: logMessage ?? '-',
        );
        return core.Err(
          SendTransactionConfirmationFailure(
            logMessage: logMessage ?? 'Failed to post the Payjoin original',
            keptPayjoinOriginalTxId: originalTxId,
          ),
        );
      case Err(:final failure):
        // Both parts: Failure has no toString() override, so passing the value
        // itself would log "Instance of 'PayjoinX'" and drop the message,
        // while passing only logMessage drops the type.
        log.warning(
          'Failed to start Payjoin send',
          error: '${failure.runtimeType}: ${failure.logMessage ?? "-"}',
        );
        return core.Err(
          SendTransactionConfirmationFailure(
            logMessage: failure.logMessage ?? 'Failed to start Payjoin send',
          ),
        );
    }
  }
}
