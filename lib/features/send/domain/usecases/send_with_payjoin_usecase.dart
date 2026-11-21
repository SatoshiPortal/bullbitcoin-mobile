import 'package:bb_mobile/core/utils/result.dart' as core;
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class SendWithPayjoinUsecase {
  final PayjoinSender _sender;
  final PayjoinSessions _sessions;

  const SendWithPayjoinUsecase(this._sender, this._sessions);

  @useResult
  Future<core.Result<PayjoinSenderSession, SendFailure>> execute({
    required String walletId,
    required bool isTestnet,
    required String bip21,
    required String unsignedOriginalPsbt,
    required int amountSat,
    required double networkFeesSatPerVb,
    int? expireAfterSec,
  }) async {
    // Whole seconds: that is the precision of a stored session's createdAt.
    final startedAt = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 * 1000,
    );
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
        return core.Ok(value);
      case Err(:final failure):
        // Both parts: Failure has no toString() override, so passing the value
        // itself would log "Instance of 'PayjoinX'" and drop the message,
        // while passing only logMessage drops the type.
        log.warning(
          'Failed to start Payjoin send',
          error: '${failure.runtimeType}: ${failure.logMessage ?? "-"}',
        );
        // The engine persists the session, signed original included, before
        // posting it. An ongoing row means the payment is in flight, and a row
        // this attempt created may already be settled by its original's
        // broadcast: adopt either, as Pay and Sell do, rather than letting
        // Confirm pay a second time. A row settled by an earlier payment to
        // the same request is not this payment, so its failure stands.
        if (await _sessions.byId(bip21)
            case Ok(value: final PayjoinSenderSession session)
            when session.isOngoing ||
                (!session.isExpired &&
                    !session.createdAt.isBefore(startedAt))) {
          log.warning(
            'Payjoin send start failed but session ${session.logRef} is '
            'persisted (status=${session.status.name}); adopting it',
          );
          return core.Ok(session);
        }
        return core.Err(
          SendTransactionConfirmationFailure(
            logMessage: failure.logMessage ?? 'Failed to start Payjoin send',
          ),
        );
    }
  }
}
