import 'package:bb_mobile/core/utils/result.dart' as core;
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class SendWithPayjoinUsecase {
  final PayjoinSender _sender;
  final PayjoinSessions _sessions;
  final PayjoinLifecycle _lifecycle;

  const SendWithPayjoinUsecase(this._sender, this._sessions, this._lifecycle);

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
    // A previous start can have succeeded before its caller lost the result.
    // The persisted session is authoritative, including terminal outcomes.
    switch (await _sessions.byId(bip21)) {
      case Ok(value: final PayjoinSenderSession session):
        if (session.walletId != walletId ||
            session.isTestnet != isTestnet ||
            session.amountSat != amountSat) {
          return const core.Err(SendPendingTransactionChangedFailure());
        }
        if (session.isExpired) break;
        if (session.isCompleted || session.isAborted) return core.Ok(session);
        // Persistence precedes publication, so a failed start may have left
        // a session without its polling/fallback workers.
        if (await _lifecycle.resume() case Err()) {
          return const core.Err(SendTransactionConfirmationFailure());
        }
        switch (await _sessions.byId(bip21)) {
          case Ok(value: final PayjoinSenderSession resumed)
              when resumed.walletId == walletId &&
                  resumed.isTestnet == isTestnet &&
                  resumed.amountSat == amountSat:
            return core.Ok(resumed);
          case _:
            return const core.Err(SendPersistenceFailure());
        }
      case Ok(value: null):
        break;
      case Ok():
        return const core.Err(SendPendingTransactionChangedFailure());
      case Err():
        return const core.Err(SendPersistenceFailure());
    }
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
        return core.Err(
          SendTransactionConfirmationFailure(
            logMessage: failure.logMessage ?? 'Failed to start Payjoin send',
          ),
        );
    }
  }
}
