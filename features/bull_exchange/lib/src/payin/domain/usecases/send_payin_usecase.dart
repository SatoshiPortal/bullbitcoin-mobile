import 'dart:async';

import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/payin_spend_answers.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:labels/labels.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/payjoin.dart';
import 'package:spend/spend.dart';

/// Sends a built payin through the account's write gate: broadcasts a
/// signed one, or hands an on-chain one to a payjoin session. An unknown
/// outcome, or one handed to payjoin, is journaled so the next start
/// reconciles it; a sent transaction is labelled as an exchange payin.
class SendPayinUsecase {
  final Exchange _exchange;
  final Spend _spend;
  final PayjoinSender _payjoinSender;
  final PayjoinSessions _payjoinSessions;
  final Labels _labels;

  const SendPayinUsecase(
    this._exchange, {
    required this._spend,
    required this._payjoinSender,
    required this._payjoinSessions,
    required this._labels,
  });

  Future<PayinSendAnswered<PayinSpend>> execute(
    ExchangeSession session,
    PayinSend<PayinSpend> effect,
  ) {
    final bitcoin = session.environment == ExchangeEnvironment.testnet
        ? BitcoinNetwork.testnet
        : BitcoinNetwork.mainnet;
    return runPayinSend(
      gate: _exchange.writeGate,
      session: session,
      effect: effect,
      now: clock.now,
      send: (built) => _send(built, bitcoin),
      journalUnknown: (orderId, network, txid) => _exchange.journalUnknownPayin(
        session,
        orderId: orderId,
        network: network,
        txid: txid,
      ),
    );
  }

  Future<PayinBroadcastOutcome> _send(
    PayinBuilt<PayinSpend> built,
    BitcoinNetwork bitcoin,
  ) async {
    final payload = built.payload;
    final PayinBroadcastOutcome outcome = switch (payload) {
      SignedBitcoinPayin(signed: final SignedBitcoinSpend signed) =>
        payinBroadcastOf(
          await _spend.broadcastBitcoin(signed),
          txid: built.txid,
        ),
      SignedLiquidPayin(signed: final SignedLiquidSpend signed) =>
        payinBroadcastOf(
          await _spend.broadcastLiquid(signed),
          txid: built.txid,
        ),
      final PayjoinPayin<PreparedBitcoinSpend> payin => await _sendPayjoin(
        built,
        payin,
        bitcoin,
      ),
      SignedBitcoinPayin() ||
      SignedLiquidPayin() ||
      PayjoinPayin() => const PayinBroadcastRefused(PayinRefusal.nodeRejected),
    };
    if (outcome case PayinBroadcastAccepted(:final txid)) {
      unawaited(_label(txid, built.walletId));
    }
    return outcome;
  }

  Future<PayinBroadcastOutcome> _sendPayjoin(
    PayinBuilt<PayinSpend> built,
    PayjoinPayin<PreparedBitcoinSpend> payin,
    BitcoinNetwork bitcoin,
  ) async {
    final PreparedPayjoinOriginal original;
    switch (await preparePayjoinOriginal(
      spend: _spend,
      prepared: payin.prepared,
      walletId: built.walletId,
      network: bitcoin,
    )) {
      case Ok(:final value):
        original = value;
      case Err(failure: SpendUnavailableFailure()):
        return const PayinBroadcastNotSent(PayinNotSentReason.walletBusy);
      case Err():
        return const PayinBroadcastRefused(PayinRefusal.payjoinNotStarted);
    }
    switch (await _payjoinSender.start(
      StartPayjoinSender(
        walletId: built.walletId,
        network: bitcoin,
        bip21Uri: payin.bip21,
        unsignedOriginalPsbt: payin.prepared.unsignedPsbt,
        preparedOriginal: original,
        amount: Sats.fromInt(payin.amountSat),
        feeRate: FeeRate(payin.feeRateSatPerVb),
        expiresAt: payin.expiresAt,
      ),
    )) {
      case Ok(value: final sender):
        unawaited(_label(sender.originalTxId, built.walletId));
        return PayinHandedToPayjoin(sender.id, sender.originalTxId);
      case Err(failure: PayjoinSpendBlockedFailure()):
        return const PayinBroadcastNotSent(PayinNotSentReason.walletBusy);
      case Err(failure: PayjoinPublicationUnknownFailure(:final originalTxId)):
        return PayinBroadcastOutcomeUnknown(originalTxId);
      case Err(:final failure):
        // The engine persists the session before posting it: a stored,
        // ongoing session of this wallet and amount is this payin in flight.
        switch (await _payjoinSessions.byTransactionId(built.txid)) {
          case Ok(:final value):
            for (final kept in value) {
              if (kept is PayjoinSenderSession &&
                  kept.isOngoing &&
                  kept.walletId == built.walletId &&
                  kept.amountSat == payin.amountSat) {
                return PayinHandedToPayjoin(kept.id, kept.originalTxId);
              }
            }
            return failure is PayjoinSenderKeptFailure
                ? PayinBroadcastOutcomeUnknown(built.txid)
                : const PayinBroadcastRefused(PayinRefusal.payjoinNotStarted);
          case Err():
            return PayinBroadcastOutcomeUnknown(built.txid);
        }
    }
  }

  Future<void> _label(String txid, String walletId) async {
    try {
      await _labels.store(
        NewLabel.tx(
          transactionId: txid,
          label: LabelSystem.exchangeSell.label,
          origin: walletId,
        ),
      );
    } on Object {
      log.warning('Could not label the exchange payin');
    }
  }
}
