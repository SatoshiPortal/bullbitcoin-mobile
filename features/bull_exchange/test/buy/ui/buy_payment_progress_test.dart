import 'package:bull_exchange/src/buy/ui/buy_payment_progress.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../buy_fixtures.dart';

const _onchainSteps = ['placed', 'in progress', 'broadcast', 'sent'];
const _lightningSteps = ['placed', 'in progress', 'paid'];

BuyOrder _order({
  OrderPayoutStatus payout = OrderPayoutStatus.notStarted,
  OrderStatus status = OrderStatus.inProgress,
  OrderPaymentMethod method = OrderPaymentMethod.liquid,
  String? txid,
}) => buyOrder(status: status, payout: payout).copyWith(
  payoutMethod: method,
  bitcoinTransactionId: method == OrderPaymentMethod.bitcoin ? txid : null,
  liquidTransactionId: method == OrderPaymentMethod.liquid ? txid : null,
);

OutcomeWatchState<BuyOrder> _watching(BuyOrder order) =>
    WatchWatching(order, 0, 0, 1);

BullPaymentProgress _progress(
  BuyOrder order, [
  OutcomeWatchState<BuyOrder>? w,
]) => buyPaymentProgress(
  steps: buyPaymentNetwork(order) == BullPaymentNetwork.lightning
      ? _lightningSteps
      : _onchainSteps,
  order: order,
  watch: w ?? _watching(order),
);

BullPaymentPhase _phase(BuyOrder order, [OutcomeWatchState<BuyOrder>? w]) =>
    buyPaymentPhase(order: order, watch: w ?? _watching(order));

void main() {
  test('the network follows the payout method', () {
    expect(buyPaymentNetwork(_order()), BullPaymentNetwork.liquid);
    expect(
      buyPaymentNetwork(_order(method: OrderPaymentMethod.bitcoin)),
      BullPaymentNetwork.bitcoin,
    );
    for (final method in [
      OrderPaymentMethod.lnAddress,
      OrderPaymentMethod.lnInvoice,
      OrderPaymentMethod.lnUrl,
    ]) {
      expect(
        buyPaymentNetwork(_order(method: method)),
        BullPaymentNetwork.lightning,
      );
    }
  });

  group('on-chain payout without a transaction', () {
    for (final method in [
      OrderPaymentMethod.bitcoin,
      OrderPaymentMethod.liquid,
    ]) {
      test('${method.name}: every payout status', () {
        for (final payout in OrderPayoutStatus.values) {
          final order = _order(payout: payout, method: method);
          final progress = _progress(order);
          final reached = switch (payout) {
            OrderPayoutStatus.inProgress ||
            OrderPayoutStatus.awaitingClaim => 1,
            // Completed ends the watch too: the rail reports it delivered.
            OrderPayoutStatus.completed => 4,
            OrderPayoutStatus.notStarted ||
            OrderPayoutStatus.scheduled ||
            OrderPayoutStatus.canceled ||
            OrderPayoutStatus.failed ||
            OrderPayoutStatus.unknown => 0,
          };
          final stopped =
              payout == OrderPayoutStatus.canceled ||
              payout == OrderPayoutStatus.failed;
          final reason = payout.name;
          final delivered = payout == OrderPayoutStatus.completed;
          expect(_phase(order), switch ((stopped, delivered)) {
            (true, _) => BullPaymentPhase.failed,
            (_, true) => BullPaymentPhase.success,
            _ => BullPaymentPhase.sending,
          }, reason: reason);
          if (delivered) {
            expect(progress.completed, reached, reason: reason);
            expect(progress.failedAt, isNull, reason: reason);
          } else if (stopped) {
            expect(progress.failedAt, reached + 1, reason: reason);
            expect(progress.completed, reached + 1, reason: reason);
          } else {
            expect(progress.completed, reached, reason: reason);
            expect(progress.failedAt, isNull, reason: reason);
            expect(
              progress.currentState,
              BullPaymentStepState.active,
              reason: reason,
            );
          }
        }
      });
    }
  });

  group('on-chain payout with a transaction', () {
    test('a sent transaction not yet completed is broadcast, not success', () {
      for (final payout in [
        OrderPayoutStatus.notStarted,
        OrderPayoutStatus.scheduled,
        OrderPayoutStatus.inProgress,
        OrderPayoutStatus.awaitingClaim,
        OrderPayoutStatus.unknown,
      ]) {
        final order = _order(payout: payout, txid: 'tx');
        final progress = _progress(order);
        expect(progress.completed, 2, reason: payout.name);
        expect(
          progress.currentState,
          BullPaymentStepState.broadcast,
          reason: payout.name,
        );
        expect(_phase(order), BullPaymentPhase.sending, reason: payout.name);
      }
    });

    test('completed with its transaction is success on the last status', () {
      for (final method in [
        OrderPaymentMethod.bitcoin,
        OrderPaymentMethod.liquid,
      ]) {
        final order = _order(
          payout: OrderPayoutStatus.completed,
          method: method,
          txid: 'tx',
        );
        expect(_phase(order), BullPaymentPhase.success);
        final progress = _progress(order);
        expect(progress.isComplete, isTrue);
        expect(progress.failedAt, isNull);
      }
    });

    test('a failed or canceled payout with a transaction is not stopped', () {
      for (final payout in [
        OrderPayoutStatus.failed,
        OrderPayoutStatus.canceled,
      ]) {
        final order = _order(payout: payout, txid: 'tx');
        expect(_phase(order), BullPaymentPhase.sending, reason: payout.name);
        final progress = _progress(order);
        expect(progress.failedAt, isNull, reason: payout.name);
        expect(progress.completed, 2, reason: payout.name);
      }
    });
  });

  group('lightning payout', () {
    test('every payout status', () {
      for (final payout in OrderPayoutStatus.values) {
        final order = _order(
          payout: payout,
          method: OrderPaymentMethod.lnAddress,
        );
        final progress = _progress(order);
        final reason = payout.name;
        switch (payout) {
          case OrderPayoutStatus.completed:
            expect(_phase(order), BullPaymentPhase.success, reason: reason);
            expect(progress.isComplete, isTrue, reason: reason);
          case OrderPayoutStatus.canceled || OrderPayoutStatus.failed:
            expect(_phase(order), BullPaymentPhase.failed, reason: reason);
            expect(progress.failedAt, 1, reason: reason);
            expect(progress.completed, 1, reason: reason);
          case OrderPayoutStatus.inProgress || OrderPayoutStatus.awaitingClaim:
            expect(_phase(order), BullPaymentPhase.sending, reason: reason);
            expect(progress.completed, 1, reason: reason);
            expect(progress.failedAt, isNull, reason: reason);
          case OrderPayoutStatus.notStarted ||
              OrderPayoutStatus.scheduled ||
              OrderPayoutStatus.unknown:
            expect(_phase(order), BullPaymentPhase.sending, reason: reason);
            expect(progress.completed, 0, reason: reason);
            expect(progress.failedAt, isNull, reason: reason);
        }
      }
    });
  });

  group('held', () {
    final states = <String, OutcomeWatchState<BuyOrder> Function(BuyOrder)>{
      'timed out': (o) => WatchTimedOut(o, 1),
      'unreadable': (o) => WatchUnreadable(o, 1),
      'paused': (o) => WatchPaused(o, 0, 0, 1),
    };
    for (final entry in states.entries) {
      test('${entry.key} holds the reached status', () {
        final inProgress = _order(payout: OrderPayoutStatus.inProgress);
        final progress = _progress(inProgress, entry.value(inProgress));
        expect(progress.completed, 1);
        expect(progress.currentState, BullPaymentStepState.held);
        expect(
          _phase(inProgress, entry.value(inProgress)),
          BullPaymentPhase.sending,
        );

        final broadcast = _order(
          payout: OrderPayoutStatus.inProgress,
          txid: 'tx',
        );
        final held = _progress(broadcast, entry.value(broadcast));
        expect(held.completed, 2);
        expect(held.currentState, BullPaymentStepState.held);
      });

      test('${entry.key} never hides a delivered payout', () {
        final done = _order(payout: OrderPayoutStatus.completed, txid: 'tx');
        expect(_phase(done, entry.value(done)), BullPaymentPhase.success);
      });

      test('${entry.key} never turns a stopped payout into held', () {
        final failed = _order(payout: OrderPayoutStatus.failed);
        expect(_phase(failed, entry.value(failed)), BullPaymentPhase.failed);
        expect(_progress(failed, entry.value(failed)).failedAt, 1);
      });
    }

    test('held lightning keeps the reached status', () {
      final order = _order(
        payout: OrderPayoutStatus.inProgress,
        method: OrderPaymentMethod.lnAddress,
      );
      final progress = _progress(order, WatchTimedOut(order, 1));
      expect(progress.completed, 1);
      expect(progress.currentState, BullPaymentStepState.held);
    });
  });

  group('failure', () {
    test('a terminal failed order status stops the payment', () {
      for (final status in [
        OrderStatus.canceled,
        OrderStatus.expired,
        OrderStatus.orderExpired,
        OrderStatus.rejected,
        OrderStatus.failed,
      ]) {
        final order = _order(
          status: status,
          payout: OrderPayoutStatus.notStarted,
        );
        expect(_phase(order), BullPaymentPhase.failed, reason: status.name);
        expect(_progress(order).failedAt, 1, reason: status.name);
      }
    });

    test('the watch failure stops the payment', () {
      final order = _order(payout: OrderPayoutStatus.inProgress);
      expect(_phase(order, WatchFailed(order)), BullPaymentPhase.failed);
      final progress = _progress(order, WatchFailed(order));
      expect(progress.failedAt, 2);
      expect(progress.completed, 2);
    });

    test('a completed order status alone does not complete the payout', () {
      final order = _order(
        status: OrderStatus.completed,
        payout: OrderPayoutStatus.inProgress,
      );
      expect(_phase(order), BullPaymentPhase.sending);
    });
  });
}
