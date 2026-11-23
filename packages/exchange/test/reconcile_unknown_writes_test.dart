import 'package:exchange/exchange.dart';
import 'package:exchange/src/session/reconcile_unknown_writes_usecase.dart';
import 'package:exchange/testing.dart';
import 'package:mocktail/mocktail.dart' show Fake;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

Order _order({
  String orderId = 'o-1',
  OrderStatus orderStatus = OrderStatus.awaitingConfirmation,
  OrderPayoutStatus payoutStatus = OrderPayoutStatus.notStarted,
  String? bitcoinTransactionId,
}) => Order.buy(
  orderId: orderId,
  orderType: OrderType.buy,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 1,
  payinAmount: 100,
  payinCurrency: 'CAD',
  payoutAmount: 0.001,
  payoutCurrency: 'BTC',
  payinMethod: OrderPaymentMethod.cadBalance,
  payoutMethod: OrderPaymentMethod.bitcoin,
  orderStatus: orderStatus,
  payinStatus: OrderPayinStatus.completed,
  payoutStatus: payoutStatus,
  createdAt: DateTime.utc(2026, 11, 23),
  bitcoinAddress: 'tb1qbuy',
  bitcoinTransactionId: bitcoinTransactionId,
  isTestnet: true,
);

LimitOrder _limitOrder({
  String address = 'bc1qlimit',
  String currencyCode = 'CAD',
  double limitPrice = 90000,
  double fiatAmount = 100,
}) => LimitOrder(
  id: 'lo-1',
  number: '1',
  fiatAmount: fiatAmount,
  currencyCode: currencyCode,
  limitPrice: limitPrice,
  estimatedBtcAmount: 0.001,
  status: LimitOrderStatus.active,
  createdAt: DateTime.utc(2026, 11, 23),
  expiresAt: DateTime.utc(2026, 12, 23),
  address: address,
);

final class _Orders extends Fake implements ExchangeOrders {
  final Map<String, Result<Order, ExchangeFailure>> answers;
  final reads = <String>[];

  _Orders(this.answers);

  @override
  Future<Result<Order, ExchangeFailure>> getOrder(String orderId) async {
    reads.add(orderId);
    return answers[orderId] ?? const Err(ExchangeNetworkFailure());
  }
}

void main() {
  group('confirm settlement', () {
    final table = {
      OrderStatus.inProgress: UnknownWriteSettlement.applied,
      OrderStatus.completed: UnknownWriteSettlement.applied,
      OrderStatus.awaitingConfirmation: UnknownWriteSettlement.notApplied,
      OrderStatus.canceled: UnknownWriteSettlement.orderEnded,
      OrderStatus.expired: UnknownWriteSettlement.orderEnded,
      OrderStatus.orderExpired: UnknownWriteSettlement.orderEnded,
      OrderStatus.rejected: UnknownWriteSettlement.orderEnded,
      OrderStatus.failed: UnknownWriteSettlement.orderEnded,
      OrderStatus.unknown: null,
    };

    test('names every order status', () {
      expect(table.keys, containsAll(OrderStatus.values));
    });

    for (final MapEntry(key: status, value: settlement) in table.entries) {
      test('$status -> $settlement', () {
        expect(confirmSettlement(_order(orderStatus: status)), settlement);
      });
    }
  });

  group('accelerate settlement', () {
    test('an open order with nothing sent stays open', () {
      expect(accelerateSettlement(_order()), isNull);
      expect(
        accelerateSettlement(_order(orderStatus: OrderStatus.inProgress)),
        isNull,
      );
    });

    test('a sent payout, a terminal payout or an ended order settle it', () {
      for (final order in [
        _order(bitcoinTransactionId: 'a' * 64),
        _order(payoutStatus: OrderPayoutStatus.completed),
        _order(orderStatus: OrderStatus.canceled),
      ]) {
        expect(accelerateSettlement(order), UnknownWriteSettlement.orderEnded);
      }
    });
  });

  group('DCA settlement', () {
    const request = {'address': 'lq1dca'};

    test('active with the address sent is applied', () {
      expect(
        dcaSettlement(
          request,
          const UserDca(isActive: true, address: 'lq1dca'),
        ),
        UnknownWriteSettlement.applied,
      );
    });

    test('inactive or another address is not applied', () {
      expect(
        dcaSettlement(request, const UserDca(isActive: false)),
        UnknownWriteSettlement.notApplied,
      );
      expect(
        dcaSettlement(
          request,
          const UserDca(isActive: true, address: 'lq1other'),
        ),
        UnknownWriteSettlement.notApplied,
      );
    });
  });

  group('limit order settlement', () {
    const request = {
      'limitPrice': '90000.00',
      'fiatAmount': '100.00',
      'currency': 'CAD',
      'address': 'bc1qlimit',
    };

    test('a matching open order is applied', () {
      expect(
        limitOrderSettlement(request, [_limitOrder()]),
        UnknownWriteSettlement.applied,
      );
    });

    test('no match stays open: the order may have executed already', () {
      for (final orders in [
        <LimitOrder>[],
        [_limitOrder(address: 'bc1qother')],
        [_limitOrder(currencyCode: 'EUR')],
        [_limitOrder(limitPrice: 89000)],
        [_limitOrder(fiatAmount: 200)],
      ]) {
        expect(limitOrderSettlement(request, orders), isNull);
      }
    });

    test('an unreadable request stays open', () {
      expect(
        limitOrderSettlement({...request, 'limitPrice': 'x'}, [_limitOrder()]),
        isNull,
      );
    });
  });

  group('default wallet settlement', () {
    const wallets = DefaultWallets(
      bitcoin: DefaultWallet(walletType: BtcNetwork.bitcoin, address: 'bc1q'),
    );

    test('the address sent on the type sent is applied', () {
      expect(
        defaultWalletSettlement(const {
          'walletType': 'bitcoin',
          'address': 'bc1q',
        }, wallets),
        UnknownWriteSettlement.applied,
      );
    });

    test('another address or an empty type is not applied', () {
      expect(
        defaultWalletSettlement(const {
          'walletType': 'bitcoin',
          'address': 'bc1qother',
        }, wallets),
        UnknownWriteSettlement.notApplied,
      );
      expect(
        defaultWalletSettlement(const {
          'walletType': 'liquid',
          'address': 'bc1q',
        }, wallets),
        UnknownWriteSettlement.notApplied,
      );
    });

    test('an unknown type stays open', () {
      expect(
        defaultWalletSettlement(const {
          'walletType': 'ark',
          'address': 'bc1q',
        }, wallets),
        isNull,
      );
    });
  });

  group('use case', () {
    late InMemoryUnknownWriteJournal journal;

    setUp(() => journal = InMemoryUnknownWriteJournal());

    Future<void> record(
      UnknownWriteKind kind, {
      String? orderId,
      Map<String, String> request = const {},
      ExchangeEnvironment environment = ExchangeEnvironment.testnet,
    }) async {
      final _ = await journal.record(
        UnknownWriteDraft(
          kind: kind,
          environment: environment,
          orderId: orderId,
          request: request,
        ),
      );
    }

    ReconcileUnknownWritesUsecase reconcile(
      _Orders orders, {
      Result<UserSummary, ExchangeFailure>? summary,
      Result<List<LimitOrder>, ExchangeFailure>? limitOrders,
      Result<DefaultWallets, ExchangeFailure>? defaultWallets,
    }) => ReconcileUnknownWritesUsecase(
      journal: journal,
      orders: (_) => orders,
      getUserSummary: (_) async =>
          summary ?? const Err(ExchangeNetworkFailure()),
      listOpenLimitOrders: () async =>
          limitOrders ?? const Err(ExchangeNetworkFailure()),
      getDefaultWallets: () async =>
          defaultWallets ?? const Err(ExchangeNetworkFailure()),
    );

    test('settles what the re-reads decide and keeps the rest open', () async {
      await record(UnknownWriteKind.buyConfirm, orderId: 'confirmed');
      await record(UnknownWriteKind.withdrawConfirm, orderId: 'unreadable');
      await record(UnknownWriteKind.buyConfirm, orderId: 'odd');
      await record(
        UnknownWriteKind.limitOrderCreate,
        request: const {
          'limitPrice': '90000.00',
          'fiatAmount': '100.00',
          'currency': 'CAD',
          'address': 'bc1qlimit',
        },
      );
      await record(
        UnknownWriteKind.defaultWalletSave,
        request: const {'walletType': 'bitcoin', 'address': 'bc1q'},
      );
      final orders = _Orders({
        'confirmed': Ok(_order(orderStatus: OrderStatus.inProgress)),
        'odd': Ok(_order(orderStatus: OrderStatus.unknown)),
      });

      final result = await reconcile(
        orders,
        limitOrders: Ok([_limitOrder()]),
        defaultWallets: const Ok(DefaultWallets()),
      ).execute(ExchangeEnvironment.testnet);

      expect(
        result,
        isA<Ok<UnknownWriteReconciliation, UnknownWriteJournalFailure>>()
            .having(
              (r) => r.value,
              'value',
              const UnknownWriteReconciliation(settled: 3, open: 2),
            ),
      );
      expect(orders.reads, ['confirmed', 'unreadable', 'odd']);
      expect(
        [for (final (e, s) in journal.entries) (e.orderId, s)],
        [
          ('confirmed', UnknownWriteSettlement.applied),
          ('unreadable', null),
          ('odd', null),
          (null, UnknownWriteSettlement.applied),
          (null, UnknownWriteSettlement.notApplied),
        ],
      );
    });

    test('only the given environment is reconciled', () async {
      await record(
        UnknownWriteKind.buyConfirm,
        orderId: 'mainnet-order',
        environment: ExchangeEnvironment.mainnet,
      );
      final orders = _Orders({
        'mainnet-order': Ok(_order(orderStatus: OrderStatus.completed)),
      });

      final _ = await reconcile(orders).execute(ExchangeEnvironment.testnet);

      expect(orders.reads, isEmpty);
      expect(journal.entries.single.$2, isNull);
    });

    test('a DCA entry is settled from the user summary', () async {
      await record(
        UnknownWriteKind.dcaCreate,
        request: const {'address': 'lq1dca'},
      );
      final summary = UserSummary(
        userNumber: 1,
        groups: const [],
        profile: const UserProfile(firstName: '', lastName: ''),
        email: '',
        balances: const [],
        dca: const UserDca(isActive: true, address: 'lq1dca'),
        autoBuy: const UserAutoBuy(
          isActive: false,
          addresses: UserAutoBuyAddresses(),
        ),
      );

      final _ = await reconcile(
        _Orders(const {}),
        summary: Ok(summary),
      ).execute(ExchangeEnvironment.testnet);

      expect(journal.entries.single.$2, UnknownWriteSettlement.applied);
    });

    test('nothing is ever sent: only reads are used', () async {
      await record(UnknownWriteKind.accelerate, orderId: 'o-1');
      final orders = _Orders({'o-1': Ok(_order())});

      final result = await reconcile(orders)
          .execute(ExchangeEnvironment.testnet);

      expect(
        result,
        isA<Ok<UnknownWriteReconciliation, UnknownWriteJournalFailure>>()
            .having(
              (r) => r.value,
              'value',
              const UnknownWriteReconciliation(settled: 0, open: 1),
            ),
      );
    });
  });

  group('Exchange.reconcileUnknownWrites', () {
    test('without a journal there is nothing to do', () async {
      expect(
        await exchangeForTesting().reconcileUnknownWrites(),
        isA<Ok<UnknownWriteReconciliation, Failure>>().having(
          (r) => r.value,
          'value',
          const UnknownWriteReconciliation(settled: 0, open: 0),
        ),
      );
    });

    test('reconciles the current environment through its reads', () async {
      final journal = InMemoryUnknownWriteJournal();
      final _ = await journal.record(
        const UnknownWriteDraft(
          kind: UnknownWriteKind.buyConfirm,
          environment: ExchangeEnvironment.mainnet,
          orderId: 'o-1',
          request: {'orderId': 'o-1'},
        ),
      );
      final exchange = exchangeForTesting(
        unknownWrites: journal,
        readSessionPoint: () async =>
            const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
        orders: (_) =>
            _Orders({'o-1': Ok(_order(orderStatus: OrderStatus.canceled))}),
      );

      final open = await exchange.openUnknownWrites();
      final result = await exchange.reconcileUnknownWrites();

      expect(
        open,
        isA<Ok<List<UnknownWrite>, Failure>>().having(
          (r) => r.value.single.orderId,
          'orderId',
          'o-1',
        ),
      );
      expect(
        result,
        isA<Ok<UnknownWriteReconciliation, Failure>>().having(
          (r) => r.value,
          'value',
          const UnknownWriteReconciliation(settled: 1, open: 0),
        ),
      );
      expect(journal.entries.single.$2, UnknownWriteSettlement.orderEnded);
    });
  });
}
