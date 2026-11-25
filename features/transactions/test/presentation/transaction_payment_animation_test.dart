import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swaps/order_swaps.dart';
import 'package:swaps/swaps.dart';
import 'package:transactions/generated/l10n/transactions_localizations_en.dart';
import 'package:transactions/testing.dart';

import 'animation_fixtures.dart';

TransactionDetailsState state(Transaction? transaction) =>
    TransactionDetailsState(transaction: transaction);

LnSendSwap lnSend() => Swap.lnSend(
  id: 'send',
  keyIndex: 0,
  type: SwapType.bitcoinToLightning,
  status: SwapStatus.paid,
  environment: SwapEnvironment.testnet,
  creationTime: DateTime.utc(2026),
  sendWalletId: 'wallet',
  invoice: 'lnbc',
  paymentAddress: 'address',
  paymentAmount: 1000,
  sendTxid: 'lockup',
) as LnSendSwap;

ChainSwap chain({
  SwapStatus status = SwapStatus.completed,
  String? receiveWalletId,
  String? receiveTxid,
}) => Swap.chain(
  id: 'chain',
  keyIndex: 0,
  type: SwapType.bitcoinToLiquid,
  status: status,
  environment: SwapEnvironment.testnet,
  creationTime: DateTime.utc(2026),
  sendWalletId: 'source',
  receiveWalletId: receiveWalletId,
  paymentAddress: 'address',
  paymentAmount: 1000,
  sendTxid: 'lockup',
  receiveTxid: receiveTxid,
) as ChainSwap;

void main() {
  final labels = TransactionsLocalizationsEn();

  group('direct wallet transaction', () {
    test('send waits for its confirmation, then succeeds', () {
      final pending = transactionPaymentAnimation(
        state(Transaction(walletTransaction: walletTx('tx'))),
        labels,
      )!;
      expect(pending.network, BullPaymentNetwork.bitcoin);
      expect(pending.direction, BullPaymentDirection.outgoing);
      expect(pending.phase, BullPaymentPhase.sending);
      expect(pending.progress.steps, ['Signing', 'Broadcasted', 'Confirmed']);
      expect(pending.progress.completed, 1);
      expect(pending.progress.currentState, BullPaymentStepState.broadcast);
      expect(pending.status, 'Pending in the mempool');

      final confirmed = transactionPaymentAnimation(
        state(Transaction(walletTransaction: walletTx('tx', confirmed: true))),
        labels,
      )!;
      expect(confirmed.phase, BullPaymentPhase.success);
      expect(confirmed.status, 'Confirmed');
    });

    test('receive is detected, then confirmed', () {
      final pending = transactionPaymentAnimation(
        state(Transaction(walletTransaction: walletTx('tx', incoming: true))),
        labels,
      )!;
      expect(pending.direction, BullPaymentDirection.incoming);
      expect(pending.progress.steps, ['Detected', 'Confirmed']);
      expect(pending.progress.completed, 0);
      expect(pending.phase, BullPaymentPhase.sending);
      final confirmed = transactionPaymentAnimation(
        state(
          Transaction(
            walletTransaction: walletTx('tx', incoming: true, confirmed: true),
          ),
        ),
        labels,
      )!;
      expect(confirmed.phase, BullPaymentPhase.success);
    });
  });

  group('Boltz swaps', () {
    final lnReceive = Swap.lnReceive(
      id: 'ln',
      keyIndex: 0,
      type: SwapType.lightningToBitcoin,
      status: SwapStatus.completed,
      environment: SwapEnvironment.testnet,
      creationTime: DateTime.utc(2026),
      receiveWalletId: 'wallet',
      invoice: 'lnbc',
      receiveTxid: 'claim',
    ) as LnReceiveSwap;

    test('Lightning receive is confirmed only by the observed claim', () {
      final transaction = Transaction(swap: lnReceive);
      final unconfirmed = transactionPaymentAnimation(
        state(transaction),
        labels,
        settlement: walletTx('claim', incoming: true),
      )!;
      expect(unconfirmed.network, BullPaymentNetwork.lightning);
      expect(unconfirmed.direction, BullPaymentDirection.incoming);
      expect(unconfirmed.progress.steps, [
        'Boltz lockup',
        'Claim broadcast',
        'Confirmed',
      ]);
      expect(unconfirmed.progress.completed, 1);
      expect(unconfirmed.phase, BullPaymentPhase.sending);

      final other = transactionPaymentAnimation(
        state(transaction),
        labels,
        settlement: walletTx('other', incoming: true, confirmed: true),
      )!;
      expect(other.phase, BullPaymentPhase.sending);

      final confirmed = transactionPaymentAnimation(
        state(transaction),
        labels,
        settlement: walletTx('claim', incoming: true, confirmed: true),
      )!;
      expect(confirmed.phase, BullPaymentPhase.success);
      expect(confirmed.progress.completed, 2);
    });

    test('Lightning send is a four status Boltz payment', () {
      final animation = transactionPaymentAnimation(
        state(Transaction(swap: lnSend())),
        labels,
      )!;
      expect(animation.network, BullPaymentNetwork.boltz);
      expect(animation.direction, BullPaymentDirection.outgoing);
      expect(animation.progress.steps, [
        'Sending lockup',
        'Lockup sent',
        'Invoice paid',
        'Completed',
      ]);
    });

    test('a chain swap to an app wallet ends on the observed claim', () {
      final transaction = Transaction(
        swap: chain(receiveWalletId: 'receiver', receiveTxid: 'claim'),
      );
      final waiting = transactionPaymentAnimation(state(transaction), labels)!;
      expect(waiting.progress.steps.last, 'Confirmed');
      expect(waiting.phase, BullPaymentPhase.sending);
      final done = transactionPaymentAnimation(
        state(transaction),
        labels,
        settlement: walletTx('claim', confirmed: true, walletId: 'receiver'),
      )!;
      expect(done.phase, BullPaymentPhase.success);
    });

    test('a refundable swap holds its refund and stays recoverable', () {
      final transaction = Transaction(
        swap: chain(status: SwapStatus.refundable),
      );
      final animation = transactionPaymentAnimation(
        state(transaction),
        labels,
      )!;
      expect(animation.progress.refund, BullPaymentRefund.available);
      expect(animation.status, 'Refund in progress');
      expect(transactionHasPendingRecovery(transaction), isTrue);
    });
  });

  group('Payjoin', () {
    test('a completed send is confirmed by its observed transaction', () {
      final transaction = Transaction(
        payjoin: senderSession(PayjoinStatus.completed, txId: 'pj'),
      );
      final broadcast = transactionPaymentAnimation(
        state(transaction),
        labels,
      )!;
      expect(broadcast.network, BullPaymentNetwork.payjoin);
      expect(broadcast.direction, BullPaymentDirection.outgoing);
      expect(broadcast.progress.completed, 2);
      expect(broadcast.phase, BullPaymentPhase.sending);
      final confirmed = transactionPaymentAnimation(
        state(transaction),
        labels,
        settlement: walletTx('pj', confirmed: true),
      )!;
      expect(confirmed.phase, BullPaymentPhase.success);
    });

    test('an aborted send skips the proposal and settles on the original', () {
      final transaction = Transaction(
        payjoin: senderSession(PayjoinStatus.aborted),
      );
      final animation = transactionPaymentAnimation(
        state(transaction),
        labels,
        settlement: walletTx('original', confirmed: true),
      )!;
      expect(animation.progress.skippedAt, 1);
      expect(animation.phase, BullPaymentPhase.success);
      expect(
        settlementTargetOf(transaction),
        const TransactionSettlementTarget(walletId: 'wallet', txId: 'original'),
      );
    });

    test('the wallet transaction decides the displayed status', () {
      final transaction = Transaction(
        payjoin: senderSession(PayjoinStatus.requested, txId: 'pj'),
        walletTransaction: walletTx('pj'),
      );
      final animation = transactionPaymentAnimation(
        state(transaction),
        labels,
      )!;
      expect(animation.progress.completed, 2);
    });

    test('a completed receive is incoming', () {
      final transaction = Transaction(
        payjoin: receiverSession(PayjoinStatus.completed, txId: 'pj'),
      );
      final animation = transactionPaymentAnimation(
        state(transaction),
        labels,
        settlement: walletTx('pj', incoming: true, confirmed: true),
      )!;
      expect(animation.direction, BullPaymentDirection.incoming);
      expect(animation.progress.steps, [
        'Original received',
        'Proposal sent',
        'Payment detected',
        'Confirmed',
      ]);
      expect(animation.phase, BullPaymentPhase.success);
    });

    test('a manual original broadcast is a pending recovery', () {
      expect(
        transactionHasPendingRecovery(
          Transaction(payjoin: senderSession(PayjoinStatus.requested)),
        ),
        isTrue,
      );
      expect(
        transactionHasPendingRecovery(
          Transaction(payjoin: senderSession(PayjoinStatus.completed)),
        ),
        isFalse,
      );
    });
  });

  group('exchange order swap', () {
    test('a payout to an app wallet waits for its confirmation', () {
      final transaction = Transaction(
        orderSwap: orderSwap(
          destinationWalletId: 'destination',
          payoutTxId: 'payout',
        ),
      );
      final waiting = transactionPaymentAnimation(state(transaction), labels)!;
      expect(waiting.network, BullPaymentNetwork.liquid);
      expect(waiting.progress.steps, [
        'Sending payin',
        'Payin broadcast',
        'Payout in progress',
        'Payout broadcast',
        'Confirmed',
      ]);
      expect(waiting.progress.completed, 3);
      expect(waiting.phase, BullPaymentPhase.sending);
      // The exchange's completion plus the confirmed payout end the payment;
      // a confirmation alone does not.
      final confirmedPayout = walletTx(
        'payout',
        confirmed: true,
        walletId: 'destination',
      );
      final early = transactionPaymentAnimation(
        state(transaction),
        labels,
        settlement: confirmedPayout,
      )!;
      expect(early.phase, BullPaymentPhase.sending);
      expect(early.progress.isComplete, isFalse);
      final completed = Transaction(
        orderSwap: orderSwap(
          status: OrderSwapLocalStatus.completed,
          destinationWalletId: 'destination',
          payoutTxId: 'payout',
        ),
      );
      final done = transactionPaymentAnimation(
        state(completed),
        labels,
        settlement: confirmedPayout,
      )!;
      expect(done.phase, BullPaymentPhase.success);
      expect(done.progress.isComplete, isTrue);
    });

    test('an external destination ends on the exchange completion', () {
      final record = orderSwap(status: OrderSwapLocalStatus.completed);
      expect(settlementTargetOf(Transaction(orderSwap: record)), isNull);
      final animation = transactionPaymentAnimation(
        state(Transaction(orderSwap: record)),
        labels,
      )!;
      expect(animation.progress.steps.last, 'Completed');
      expect(animation.phase, BullPaymentPhase.success);
    });

    test('a swap paid from outside the app has no animation', () {
      final record = orderSwap(
        sourceWalletId: null,
        destinationWalletId: 'destination',
      );
      expect(
        transactionPaymentAnimation(
          state(Transaction(orderSwap: record)),
          labels,
        ),
        isNull,
      );
    });

    test('an order swap beats the wallet transaction it holds', () {
      final animation = transactionPaymentAnimation(
        state(
          Transaction(
            orderSwap: orderSwap(),
            walletTransaction: walletTx('payin'),
          ),
        ),
        labels,
      )!;
      expect(animation.progress.steps.first, 'Sending payin');
    });
  });

  group('Buy order', () {
    test('a Bitcoin payout is shown from the order snapshot', () {
      final animation = transactionPaymentAnimation(
        state(Transaction(order: buyOrder())),
        labels,
      )!;
      expect(animation.network, BullPaymentNetwork.bitcoin);
      expect(animation.direction, BullPaymentDirection.incoming);
      expect(animation.progress.steps, [
        'Order placed',
        'Payout in progress',
        'Payout broadcast',
        'Payout sent',
      ]);
      expect(animation.progress.completed, 1);
      expect(animation.phase, BullPaymentPhase.sending);
    });

    test('a Lightning payout has three statuses and completes', () {
      final animation = transactionPaymentAnimation(
        state(
          Transaction(
            order: buyOrder(
              payout: OrderPayoutStatus.completed,
              method: OrderPaymentMethod.lnInvoice,
            ),
          ),
        ),
        labels,
      )!;
      expect(animation.network, BullPaymentNetwork.lightning);
      expect(animation.progress.steps.length, 3);
      expect(animation.phase, BullPaymentPhase.success);
    });
  });

  group('no animation', () {
    test('while loading', () {
      expect(transactionPaymentAnimation(state(null), labels), isNull);
    });

    test('for an order without a payout to show', () {
      expect(
        transactionPaymentAnimation(
          state(Transaction(order: sellOrder())),
          labels,
        ),
        isNull,
      );
    });

    test('for an empty transaction', () {
      expect(
        transactionPaymentAnimation(state(const Transaction()), labels),
        isNull,
      );
    });
  });

  group('settlement target', () {
    test('is the transaction itself for a direct wallet transaction', () {
      expect(
        settlementTargetOf(Transaction(walletTransaction: walletTx('tx'))),
        const TransactionSettlementTarget(walletId: 'wallet', txId: 'tx'),
      );
    });

    test('is null for a swap that pays nobody of this app', () {
      expect(settlementTargetOf(Transaction(swap: lnSend())), isNull);
      expect(settlementTargetOf(null), isNull);
    });

    test('is the payout only when the destination is an app wallet', () {
      expect(
        settlementTargetOf(
          Transaction(
            orderSwap: orderSwap(
              destinationWalletId: 'destination',
              payoutTxId: 'payout',
            ),
          ),
        ),
        const TransactionSettlementTarget(
          walletId: 'destination',
          txId: 'payout',
          isLiquid: true,
        ),
      );
      expect(
        settlementTargetOf(
          Transaction(orderSwap: orderSwap(payoutTxId: 'payout')),
        ),
        isNull,
      );
    });
  });
}
