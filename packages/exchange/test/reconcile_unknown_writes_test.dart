import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/src/recipients/domain/recipient_identity.dart';
import 'package:exchange/src/session/reconcile_unknown_writes_usecase.dart';
import 'package:exchange/testing.dart';
import 'package:mocktail/mocktail.dart' show Fake;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

Order _order({
  String orderId = 'o-1',
  OrderStatus orderStatus = OrderStatus.awaitingConfirmation,
  OrderPayoutStatus payoutStatus = OrderPayoutStatus.notStarted,
  OrderPayinStatus payinStatus = OrderPayinStatus.completed,
  String? bitcoinTransactionId,
  double payinAmount = 100,
  double payoutAmount = 0.001,
  DateTime? createdAt,
}) => Order.buy(
  orderId: orderId,
  orderType: OrderType.buy,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 1,
  payinAmount: payinAmount,
  payinCurrency: 'CAD',
  payoutAmount: payoutAmount,
  payoutCurrency: 'BTC',
  payinMethod: OrderPaymentMethod.cadBalance,
  payoutMethod: OrderPaymentMethod.bitcoin,
  orderStatus: orderStatus,
  payinStatus: payinStatus,
  payoutStatus: payoutStatus,
  createdAt: createdAt ?? DateTime.utc(2026, 11, 23),
  bitcoinAddress: 'tb1qbuy',
  bitcoinTransactionId: bitcoinTransactionId,
  isTestnet: true,
);

LimitOrder _limitOrder({
  String address = 'bc1qlimit',
  String currencyCode = 'CAD',
  double limitPrice = 90000,
  double fiatAmount = 100,
  LimitOrderStatus status = LimitOrderStatus.active,
}) => LimitOrder(
  id: 'lo-1',
  number: '1',
  fiatAmount: fiatAmount,
  currencyCode: currencyCode,
  limitPrice: limitPrice,
  estimatedBtcAmount: 0.001,
  status: status,
  createdAt: DateTime.utc(2026, 11, 23),
  expiresAt: DateTime.utc(2026, 12, 23),
  address: address,
);

final class _Orders extends Fake implements OrdersRepository {
  final Map<String, Result<Order, ExchangeFailure>> answers;
  final Result<List<Order>, ExchangeFailure> recent;
  final reads = <String>[];
  final listedTypes = <OrderType?>[];

  _Orders(this.answers, {this.recent = const Err(ExchangeNetworkFailure())});

  @override
  Future<Result<List<Order>, ExchangeFailure>> getOrders({
    int? limit,
    int? offset,
    OrderType? type,
  }) async {
    listedTypes.add(type);
    return recent;
  }

  @override
  Future<Result<Order, ExchangeFailure>> getOrder(String orderId) async {
    reads.add(orderId);
    return answers[orderId] ?? const Err(ExchangeNetworkFailure());
  }
}

Recipient _recipient(RecipientDetails details, {String id = 'r-1'}) =>
    Recipient.create(
      recipientId: id,
      userId: 'u-1',
      userNbr: 1,
      isArchived: false,
      createdAt: DateTime.utc(2026, 11, 23),
      updatedAt: DateTime.utc(2026, 11, 23),
      details: details,
    );

final class _Recipients extends Fake implements RecipientsRepository {
  final List<Result<RecipientPage, RecipientsFailure>> pages;
  final reads = <int>[];

  _Recipients(this.pages);

  @override
  Future<Result<RecipientPage, RecipientsFailure>> listRecipients({
    required bool isTestnet,
    bool fiatOnly = true,
    int page = 1,
    int pageSize = 50,
    List<RecipientType>? recipientTypes,
    bool? isOwner,
    String? search,
  }) async {
    reads.add(page);
    return page <= pages.length
        ? pages[page - 1]
        : const Ok((recipients: <Recipient>[], totalRecipients: 0));
  }
}

UserSummary _summary({
  String? language = 'en',
  String? currency = 'CAD',
  bool dcaActive = false,
  bool autoBuyActive = false,
  bool emailNotifications = true,
  String? dcaAddress,
}) => UserSummary(
  userNumber: 1,
  groups: const [],
  profile: const UserProfile(firstName: '', lastName: ''),
  email: '',
  balances: const [],
  language: language,
  currency: currency,
  emailNotificationsEnabled: emailNotifications,
  dca: UserDca(isActive: dcaActive, address: dcaAddress),
  autoBuy: UserAutoBuy(
    isActive: autoBuyActive,
    addresses: const UserAutoBuyAddresses(),
  ),
);

void main() {
  group('payin settlement', () {
    final table = {
      OrderPayinStatus.inProgress: UnknownWriteSettlement.applied,
      OrderPayinStatus.underReview: UnknownWriteSettlement.applied,
      OrderPayinStatus.awaitingConfirmation: UnknownWriteSettlement.applied,
      OrderPayinStatus.completed: UnknownWriteSettlement.applied,
      OrderPayinStatus.rejected: UnknownWriteSettlement.applied,
      OrderPayinStatus.notStarted: null,
      OrderPayinStatus.awaitingPayment: null,
      OrderPayinStatus.unknown: null,
    };

    test('names every payin status', () {
      expect(table.keys, containsAll(OrderPayinStatus.values));
    });

    for (final MapEntry(key: status, value: settlement) in table.entries) {
      test('$status on a live order -> $settlement', () {
        expect(
          payinSettlement(
            _order(orderStatus: OrderStatus.inProgress, payinStatus: status),
          ),
          settlement,
        );
      });
    }

    test('an order that ended without seeing the payin ends the entry', () {
      for (final status in [
        OrderStatus.expired,
        OrderStatus.orderExpired,
        OrderStatus.canceled,
      ]) {
        expect(
          payinSettlement(
            _order(
              orderStatus: status,
              payinStatus: OrderPayinStatus.awaitingPayment,
            ),
          ),
          UnknownWriteSettlement.orderEnded,
        );
      }
    });

    test('the use case re-reads the order and settles a seen payin', () async {
      final journal = InMemoryUnknownWriteJournal();
      final _ = await journal.record(
        const UnknownWriteDraft(
          kind: UnknownWriteKind.payin,
          environment: ExchangeEnvironment.testnet,
          orderId: 'o-1',
          request: {'orderId': 'o-1', 'network': 'bitcoin', 'txid': 't1'},
        ),
      );
      final orders = _Orders({
        'o-1': Ok(
          _order(
            orderStatus: OrderStatus.inProgress,
            payinStatus: OrderPayinStatus.awaitingConfirmation,
          ),
        ),
      });
      final result = await ReconcileUnknownWritesUsecase(
        journal: journal,
        orders: (_) => orders,
        getUserSummary: (_) async => const Err(ExchangeNetworkFailure()),
        listRecentLimitOrders: () async => const Err(ExchangeNetworkFailure()),
        getDefaultWallets: () async => const Err(ExchangeNetworkFailure()),
        recipients: _Recipients([const Err(RecipientsNetworkFailure())]),
      ).execute(ExchangeEnvironment.testnet);

      expect(orders.reads, ['o-1']);
      expect(
        result,
        isA<Ok<UnknownWriteReconciliation, UnknownWriteJournalFailure>>()
            .having(
              (r) => r.value,
              'value',
              const UnknownWriteReconciliation(settled: 1, open: 0),
            ),
      );
    });

    test('Exchange.journalUnknownPayin records the order and txid', () async {
      final journal = InMemoryUnknownWriteJournal();
      final exchange = exchangeForTesting(unknownWrites: journal);

      await exchange.journalUnknownPayin(
        const ExchangeSession(
          environment: ExchangeEnvironment.mainnet,
          epoch: 3,
          sessionId: 's',
        ),
        orderId: 'o-1',
        network: BtcNetwork.liquid,
        txid: 't1',
      );

      final open = await journal.open(ExchangeEnvironment.mainnet);
      expect(
        open,
        isA<Ok<List<UnknownWrite>, UnknownWriteJournalFailure>>().having(
          (r) => r.value.single,
          'entry',
          isA<UnknownWrite>()
              .having((e) => e.kind, 'kind', UnknownWriteKind.payin)
              .having((e) => e.orderId, 'orderId', 'o-1')
              .having((e) => e.sessionEpoch, 'epoch', 3)
              .having((e) => e.request, 'request', {
                'orderId': 'o-1',
                'network': 'liquid',
                'txid': 't1',
              }),
        ),
      );
    });
  });

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

    test('a sent or completed payout finishes it: applied', () {
      for (final order in [
        _order(bitcoinTransactionId: 'a' * 64),
        _order(payoutStatus: OrderPayoutStatus.completed),
        _order(
          orderStatus: OrderStatus.completed,
          payoutStatus: OrderPayoutStatus.completed,
        ),
      ]) {
        expect(accelerateSettlement(order), UnknownWriteSettlement.applied);
      }
    });

    test('an order or payout that ended without a payout settles it', () {
      for (final order in [
        _order(orderStatus: OrderStatus.canceled),
        _order(orderStatus: OrderStatus.failed),
        _order(payoutStatus: OrderPayoutStatus.canceled),
        _order(payoutStatus: OrderPayoutStatus.failed),
      ]) {
        expect(accelerateSettlement(order), UnknownWriteSettlement.orderEnded);
      }
    });

    test('an unknown status stays open', () {
      expect(
        accelerateSettlement(
          _order(
            orderStatus: OrderStatus.unknown,
            payoutStatus: OrderPayoutStatus.unknown,
          ),
        ),
        isNull,
      );
    });
  });

  group('order create settlement', () {
    final recordedAt = DateTime.utc(2026, 11, 24, 8);
    const sent = OrderCreateJournalRequest(
      type: OrderType.buy,
      amount: FiatAmount(100),
      currency: FiatCurrency.cad,
    );

    UnknownWrite entryFor(OrderCreateJournalRequest request) => UnknownWrite(
      id: 'e-1',
      kind: UnknownWriteKind.orderCreate,
      environment: ExchangeEnvironment.testnet,
      request: request.toRequest(),
      recordedAt: recordedAt,
    );

    Order created({
      Duration before = const Duration(minutes: 1),
      double payinAmount = 100,
      double payoutAmount = 0.001,
    }) => _order(
      createdAt: recordedAt.subtract(before),
      payinAmount: payinAmount,
      payoutAmount: payoutAmount,
    );

    test('the request survives the journal', () {
      final read = OrderCreateJournalRequest.fromRequest(
        const OrderCreateJournalRequest(
          type: OrderType.fiatPayment,
          amount: BitcoinAmount(0.0005),
          recipientId: 'r-1',
        ).toRequest(),
      )!;
      expect(read.type, OrderType.fiatPayment);
      expect(read.amount, isA<BitcoinAmount>());
      expect(read.amount.amount, 0.0005);
      expect(read.currency, isNull);
      expect(read.recipientId, 'r-1');
      expect(sent.toRequest(), {
        'orderType': 'buy',
        'amount': '100.0',
        'amountKind': 'fiat',
        'currency': 'CAD',
      });
    });

    test('a request it did not write reads as null', () {
      for (final request in <Map<String, String>>[
        {},
        {'orderType': 'buy', 'amount': 'x', 'amountKind': 'fiat'},
        {'orderType': 'other', 'amount': '1', 'amountKind': 'fiat'},
        {'orderType': 'buy', 'amount': '1', 'amountKind': 'other'},
        {
          'orderType': 'buy',
          'amount': '1',
          'amountKind': 'fiat',
          'currency': 'XYZ',
        },
      ]) {
        expect(OrderCreateJournalRequest.fromRequest(request), isNull);
      }
    });

    test('an order of the type and amount sent, created in the window, '
        'is applied', () {
      for (final order in [
        created(),
        created(before: orderCreateWindow),
        created(before: const Duration(seconds: -30)),
      ]) {
        expect(
          orderCreateSettlement(entryFor(sent), [order]),
          UnknownWriteSettlement.applied,
        );
      }
    });

    test('a bitcoin amount matches to the sat', () {
      const bitcoin = OrderCreateJournalRequest(
        type: OrderType.buy,
        amount: BitcoinAmount(0.001),
        currency: FiatCurrency.cad,
      );
      expect(
        orderCreateSettlement(entryFor(bitcoin), [created()]),
        UnknownWriteSettlement.applied,
      );
      expect(
        orderCreateSettlement(entryFor(bitcoin), [
          created(payoutAmount: 0.00100001),
        ]),
        isNull,
      );
    });

    test('no match stays open', () {
      for (final orders in [
        <Order>[],
        [created(payinAmount: 101)],
        [created(before: orderCreateWindow + const Duration(seconds: 1))],
        [created(before: const Duration(minutes: -2))],
      ]) {
        expect(orderCreateSettlement(entryFor(sent), orders), isNull);
      }
      const sell = OrderCreateJournalRequest(
        type: OrderType.sell,
        amount: FiatAmount(100),
        currency: FiatCurrency.cad,
      );
      expect(orderCreateSettlement(entryFor(sell), [created()]), isNull);
    });

    test('findCreatedOrder returns the matching order, for a flow re-read', () {
      final match = created();
      final entry = entryFor(sent);
      expect(
        findCreatedOrder(sent, entry.recordedAt, [
          created(payinAmount: 101),
          match,
        ]),
        same(match),
      );
      expect(
        findCreatedOrder(sent, entry.recordedAt, [created(payinAmount: 101)]),
        isNull,
      );
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

    test('a matching order in any status is applied', () {
      for (final status in LimitOrderStatus.values) {
        expect(
          limitOrderSettlement(request, [_limitOrder(status: status)]),
          UnknownWriteSettlement.applied,
          reason: '$status',
        );
      }
    });

    test('no match in the recent page stays open', () {
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

    test('the match a flow re-reads with is the same one, and names the '
        'order', () {
      final created = _limitOrder();
      expect(
        findCreatedLimitOrder(request, [
          _limitOrder(address: 'bc1qother'),
          created,
        ]),
        same(created),
      );
      expect(
        LimitOrderDraft(
          limitPrice: 90000,
          fiatAmount: 100,
          currency: FiatCurrency.cad,
          address: 'bc1qlimit',
        ).journalRequest,
        request,
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

  group('recipient settlement', () {
    final interac = InteracEmailCadDetails.create(
      email: 'Sat@Example.com',
      name: 'Satoshi',
      securityQuestion: 'colour?',
      securityAnswer: 'orange',
    );
    final request = recipientIdentity(interac);

    test('the identity holds the type and the account, never the answer', () {
      expect(request, {'type': 'interacEmailCad', 'email': 'sat@example.com'});
    });

    test('a recipient with the same identity is applied', () {
      expect(
        recipientSettlement(request, [
          _recipient(
            InteracEmailCadDetails.create(
              email: 'sat@example.com ',
              name: 'Someone else',
            ),
          ),
        ]),
        UnknownWriteSettlement.applied,
      );
    });

    test('another account or another type is not applied', () {
      expect(
        recipientSettlement(request, [
          _recipient(
            InteracEmailCadDetails.create(email: 'hal@example.com', name: 'H'),
          ),
          _recipient(SinpeMovilCrcDetails.create(phoneNumber: '88887777')),
        ]),
        UnknownWriteSettlement.notApplied,
      );
      expect(
        recipientSettlement(request, []),
        UnknownWriteSettlement.notApplied,
      );
    });

    test('a confidential SEPA recipient does not match a plain one', () {
      final plain = SepaEurDetails.create(
        iban: 'DE89 3704 0044 0532 0130 00',
        isCorporate: false,
        firstname: 'A',
        lastname: 'B',
      );
      final confidential = SepaEurDetails.create(
        iban: 'DE89370400440532013000',
        isCorporate: false,
        firstname: 'A',
        lastname: 'B',
        isConfidential: true,
      );
      expect(
        recipientSettlement(recipientIdentity(confidential), [
          _recipient(plain),
        ]),
        UnknownWriteSettlement.notApplied,
      );
      expect(
        recipientSettlement(recipientIdentity(plain), [_recipient(plain)]),
        UnknownWriteSettlement.applied,
      );
    });
  });

  group('preferences settlement', () {
    final table = <(Map<String, String>, UserSummary), UnknownWriteSettlement>{
      ({'dcaEnabled': 'false'}, _summary()): UnknownWriteSettlement.applied,
      ({'dcaEnabled': 'true'}, _summary()): UnknownWriteSettlement.notApplied,
      (
        {'currency': 'EUR', 'language': 'fr'},
        _summary(currency: 'EUR', language: 'fr'),
      ): UnknownWriteSettlement.applied,
      ({'currency': 'EUR', 'language': 'fr'}, _summary(currency: 'EUR')):
          UnknownWriteSettlement.notApplied,
      ({'autoBuyEnabled': 'true'}, _summary(autoBuyActive: true)):
          UnknownWriteSettlement.applied,
      ({'emailNotificationsEnabled': 'false'}, _summary()):
          UnknownWriteSettlement.notApplied,
      ({'currency': 'CAD'}, _summary(currency: null)):
          UnknownWriteSettlement.notApplied,
    };
    for (final MapEntry(key: (request, summary), value: settlement)
        in table.entries) {
      test('$request -> $settlement', () {
        expect(preferencesSettlement(request, summary), settlement);
      });
    }
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
      _Recipients? recipients,
    }) => ReconcileUnknownWritesUsecase(
      journal: journal,
      orders: (_) => orders,
      getUserSummary: (_) async =>
          summary ?? const Err(ExchangeNetworkFailure()),
      listRecentLimitOrders: () async =>
          limitOrders ?? const Err(ExchangeNetworkFailure()),
      getDefaultWallets: () async =>
          defaultWallets ?? const Err(ExchangeNetworkFailure()),
      recipients:
          recipients ?? _Recipients([const Err(RecipientsNetworkFailure())]),
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

    group('maximum age', () {
      final recordedAt = DateTime.utc(2026, 11, 24, 8);

      Future<void> recordAt(String orderId) => withClock(
        Clock.fixed(recordedAt),
        () => record(UnknownWriteKind.buyConfirm, orderId: orderId),
      );

      Future<UnknownWriteReconciliation> reconcileAfter(
        Duration after,
        _Orders orders,
      ) => withClock(Clock.fixed(recordedAt.add(after)), () async {
        final result = await reconcile(orders)
            .execute(ExchangeEnvironment.testnet);
        return (result
                as Ok<UnknownWriteReconciliation, UnknownWriteJournalFailure>)
            .value;
      });

      final over = UnknownWrite.maxAge + const Duration(minutes: 1);

      test('an undecided entry within maxAge stays open', () async {
        await recordAt('unreadable');
        final result = await reconcileAfter(UnknownWrite.maxAge, _Orders({}));
        expect(result, const UnknownWriteReconciliation(settled: 0, open: 1));
        expect(journal.entries.single.$2, isNull);
      });

      test('an undecided entry past maxAge is closed as expired', () async {
        await recordAt('unreadable');
        await recordAt('odd');
        final result = await reconcileAfter(
          over,
          _Orders({'odd': Ok(_order(orderStatus: OrderStatus.unknown))}),
        );
        expect(result, const UnknownWriteReconciliation(settled: 2, open: 0));
        expect(
          [for (final (_, settlement) in journal.entries) settlement],
          [UnknownWriteSettlement.expired, UnknownWriteSettlement.expired],
        );
      });

      test('a re-read that decides wins over the age', () async {
        await recordAt('confirmed');
        final _ = await reconcileAfter(
          over,
          _Orders({
            'confirmed': Ok(_order(orderStatus: OrderStatus.completed)),
          }),
        );
        expect(journal.entries.single.$2, UnknownWriteSettlement.applied);
      });
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

    test('a recipient entry is settled from every page of the list', () async {
      final wanted = InteracEmailCadDetails.create(
        email: 'sat@example.com',
        name: 'Satoshi',
      );
      await record(
        UnknownWriteKind.recipientCreate,
        request: recipientIdentity(wanted),
      );
      final other = _recipient(
        InteracEmailCadDetails.create(email: 'hal@example.com', name: 'H'),
      );
      final recipients = _Recipients([
        Ok((recipients: [other], totalRecipients: 2)),
        Ok((recipients: [_recipient(wanted, id: 'r-2')], totalRecipients: 2)),
      ]);

      final _ = await reconcile(
        _Orders(const {}),
        recipients: recipients,
      ).execute(ExchangeEnvironment.testnet);

      expect(recipients.reads, [1, 2]);
      expect(journal.entries.single.$2, UnknownWriteSettlement.applied);
    });

    test('a complete list without the recipient is not applied', () async {
      await record(
        UnknownWriteKind.recipientCreate,
        request: const {'type': 'interacEmailCad', 'email': 'sat@example.com'},
      );

      final _ = await reconcile(
        _Orders(const {}),
        recipients: _Recipients([
          const Ok((recipients: <Recipient>[], totalRecipients: 0)),
        ]),
      ).execute(ExchangeEnvironment.testnet);

      expect(journal.entries.single.$2, UnknownWriteSettlement.notApplied);
    });

    test('a page that fails keeps the recipient entry open', () async {
      await record(
        UnknownWriteKind.recipientCreate,
        request: const {'type': 'interacEmailCad', 'email': 'sat@example.com'},
      );
      final other = _recipient(
        InteracEmailCadDetails.create(email: 'hal@example.com', name: 'H'),
      );

      final _ = await reconcile(
        _Orders(const {}),
        recipients: _Recipients([
          Ok((recipients: [other], totalRecipients: 2)),
          const Err(RecipientsNetworkFailure()),
        ]),
      ).execute(ExchangeEnvironment.testnet);

      expect(journal.entries.single.$2, isNull);
    });

    test('a preferences entry is settled from the user summary', () async {
      await record(
        UnknownWriteKind.preferencesSave,
        request: const {'dcaEnabled': 'false'},
      );

      final _ = await reconcile(
        _Orders(const {}),
        summary: Ok(_summary()),
      ).execute(ExchangeEnvironment.testnet);

      expect(journal.entries.single.$2, UnknownWriteSettlement.applied);
    });

    test('an unreadable summary keeps the preferences entry open', () async {
      await record(
        UnknownWriteKind.preferencesSave,
        request: const {'dcaEnabled': 'false'},
      );

      final _ = await reconcile(_Orders(const {}))
          .execute(ExchangeEnvironment.testnet);

      expect(journal.entries.single.$2, isNull);
    });

    group('order create entry', () {
      final recordedAt = DateTime.utc(2026, 11, 24, 8);
      const sent = OrderCreateJournalRequest(
        type: OrderType.buy,
        amount: FiatAmount(100),
        currency: FiatCurrency.cad,
      );

      Future<void> recordCreate() => withClock(
        Clock.fixed(recordedAt),
        () => record(UnknownWriteKind.orderCreate, request: sent.toRequest()),
      );

      Future<void> reconcileWith(_Orders orders) => withClock(
        Clock.fixed(recordedAt.add(const Duration(minutes: 5))),
        () async {
          final _ = await reconcile(orders)
              .execute(ExchangeEnvironment.testnet);
        },
      );

      test('is settled from the recent orders of its type', () async {
        await recordCreate();
        final orders = _Orders(
          const {},
          recent: Ok([
            _order(createdAt: recordedAt.subtract(const Duration(minutes: 1))),
          ]),
        );

        await reconcileWith(orders);

        expect(orders.listedTypes, [OrderType.buy]);
        expect(orders.reads, isEmpty);
        expect(journal.entries.single.$2, UnknownWriteSettlement.applied);
      });

      test('stays open when the orders can\'t be read or none match', () async {
        await recordCreate();
        for (final orders in [
          _Orders(const {}),
          _Orders(const {}, recent: const Ok([])),
        ]) {
          await reconcileWith(orders);
          expect(journal.entries.single.$2, isNull);
        }
      });
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
        await exchangeForTesting().reconcileUnknownWrites(
          const ExchangeSession(
            environment: ExchangeEnvironment.mainnet,
            epoch: 1,
            sessionId: 's',
          ),
        ),
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
      const session = ExchangeSession(
        environment: ExchangeEnvironment.mainnet,
        epoch: 1,
        sessionId: 's',
      );
      final exchange = exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(session)),
        unknownWrites: journal,
        readSessionPoint: () async =>
            const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
        orders: (_) =>
            _Orders({'o-1': Ok(_order(orderStatus: OrderStatus.canceled))}),
      );

      final open = await exchange.openUnknownWrites(session);
      final result = await exchange.reconcileUnknownWrites(session);

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
