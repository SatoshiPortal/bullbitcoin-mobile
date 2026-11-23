import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/journaling_exchange_orders.dart';
import 'package:exchange/testing.dart';
import 'package:mocktail/mocktail.dart' show Fake;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'bbx_api_test_http.dart';

final class _Orders extends Fake implements ExchangeOrders {
  final ExchangeWrite<Never> Function() answer;

  _Orders(this.answer);

  ExchangeWrite<T> _write<T>() => switch (answer()) {
    WriteOutcomeUnknown(:final reason) => WriteOutcomeUnknown<T>(reason),
    WriteRefused(:final reason) => WriteRefused<T>(reason),
    WriteNotSent(:final reason) => WriteNotSent<T>(reason),
    WriteSessionRejected() => WriteSessionRejected<T>(),
    WriteDone() => throw StateError('use _DoneOrders'),
  };

  @override
  Future<ExchangeWrite<BuyOrder>> confirmBuyOrder(String orderId) async =>
      _write();

  @override
  Future<ExchangeWrite<WithdrawOrder>> confirmWithdrawOrder(
    String orderId, {
    ({
      String recipientId,
      String email,
      String? securityQuestion,
      String? securityAnswer,
    })?
    interacUpdate,
  }) async => _write();

  @override
  Future<ExchangeWrite<BuyOrder>> accelerateBuyOrder(String orderId) async =>
      _write();

  @override
  Future<ExchangeWrite<Dca>> createDca({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
    required BtcNetwork network,
    required String address,
    bool enablePreference = false,
  }) async => _write();
}

typedef _Call = Future<ExchangeWrite<Object?>> Function(ExchangeOrders);

final Map<UnknownWriteKind, (_Call, Map<String, String>, String?)> _calls = {
  UnknownWriteKind.buyConfirm: (
    (orders) => orders.confirmBuyOrder('o-1'),
    {'orderId': 'o-1'},
    'o-1',
  ),
  UnknownWriteKind.withdrawConfirm: (
    (orders) => orders.confirmWithdrawOrder(
      'o-2',
      interacUpdate: (
        recipientId: 'r-1',
        email: 'sat@example.com',
        securityQuestion: 'colour?',
        securityAnswer: 'orange',
      ),
    ),
    {'orderId': 'o-2', 'interacUpdate': 'true'},
    'o-2',
  ),
  UnknownWriteKind.accelerate: (
    (orders) => orders.accelerateBuyOrder('o-3'),
    {'orderId': 'o-3'},
    'o-3',
  ),
  UnknownWriteKind.dcaCreate: (
    (orders) => orders.createDca(
      amount: 25.5,
      currency: FiatCurrency.cad,
      frequency: DcaBuyFrequency.weekly,
      network: BtcNetwork.liquid,
      address: 'lq1dca',
    ),
    {
      'amount': '25.5',
      'currency': 'CAD',
      'frequency': 'weekly',
      'network': 'liquid',
      'address': 'lq1dca',
    },
    null,
  ),
};

void main() {
  JournalingExchangeOrders journaling(
    ExchangeOrders orders,
    UnknownWriteJournal journal,
  ) => JournalingExchangeOrders(
    orders,
    UnknownWriteRecorder(journal),
    environment: ExchangeEnvironment.testnet,
    readEpoch: () async => 4,
  );

  group('order writes', () {
    for (final MapEntry(key: kind, value: (call, request, orderId))
        in _calls.entries) {
      test('$kind with an unknown outcome is journaled first', () async {
        final journal = InMemoryUnknownWriteJournal();
        final orders = journaling(
          _Orders(() => const WriteOutcomeUnknown('receive timeout')),
          journal,
        );

        final write = await call(orders);

        expect(write, isA<WriteOutcomeUnknown<Object?>>());
        final (entry, settlement) = journal.entries.single;
        expect(settlement, isNull);
        expect(entry.kind, kind);
        expect(entry.environment, ExchangeEnvironment.testnet);
        expect(entry.sessionEpoch, 4);
        expect(entry.orderId, orderId);
        expect(entry.request, request);
      });

      for (final answer in <ExchangeWrite<Never>>[
        const WriteRefused(ExchangeRefusal(rpcCode: -1)),
        const WriteNotSent(ExchangeNotSentReason.unreachable),
        const WriteSessionRejected(),
      ]) {
        test('$kind answered ${answer.runtimeType} is not journaled', () async {
          final journal = InMemoryUnknownWriteJournal();

          final _ = await call(journaling(_Orders(() => answer), journal));

          expect(journal.entries, isEmpty);
        });
      }
    }

    test('the Interac answer never reaches the journal', () async {
      final journal = InMemoryUnknownWriteJournal();
      final (call, _, _) = _calls[UnknownWriteKind.withdrawConfirm]!;

      final _ = await call(
        journaling(_Orders(() => const WriteOutcomeUnknown('x')), journal),
      );

      final values = journal.entries.single.$1.request.values.join(' ');
      expect(values, isNot(contains('orange')));
      expect(values, isNot(contains('colour')));
      expect(values, isNot(contains('sat@example.com')));
    });
  });

  group('through Exchange', () {
    Exchange exchangeOver(FakeBbxHttp http, UnknownWriteJournal journal) =>
        exchangeWithTransportForTesting(
          readSession: () async => const Ok((
            environment: ExchangeEnvironment.testnet,
            epoch: 7,
            apiKey: 'key',
          )),
          openClient: (endpoint, readKey) => bbxForTesting(
            endpoint: endpoint.toString(),
            adapter: http,
            readActiveApiKey: readKey,
          ),
          unknownWrites: journal,
        );

    test('a buy confirm that times out after sending is journaled', () async {
      final journal = InMemoryUnknownWriteJournal();
      final exchange = exchangeOver(
        FakeBbxHttp(error: DioExceptionType.receiveTimeout),
        journal,
      );

      final write = await exchange
          .orders(ExchangeEnvironment.testnet)
          .confirmBuyOrder('o-9');

      expect(write, isA<WriteOutcomeUnknown<BuyOrder>>());
      final entry = journal.entries.single.$1;
      expect(entry.kind, UnknownWriteKind.buyConfirm);
      expect(entry.orderId, 'o-9');
      expect(entry.sessionEpoch, 7);
    });

    test('a limit-order create with an unknown outcome is journaled', () async {
      final journal = InMemoryUnknownWriteJournal();
      final exchange = exchangeOver(
        FakeBbxHttp(error: DioExceptionType.receiveTimeout),
        journal,
      );

      final result = await exchange.limitOrders.create(
        LimitOrderDraft(
          limitPrice: 90000,
          fiatAmount: 100,
          currency: FiatCurrency.cad,
          address: 'bc1qlimit',
        ),
      );

      expect(result, isA<Err<LimitOrder, ExchangeFailure>>());
      final entry = journal.entries.single.$1;
      expect(entry.kind, UnknownWriteKind.limitOrderCreate);
      expect(entry.environment, ExchangeEnvironment.testnet);
      expect(entry.sessionEpoch, 7);
      expect(entry.request, {
        'limitPrice': '90000.00',
        'fiatAmount': '100.00',
        'currency': 'CAD',
        'address': 'bc1qlimit',
      });
    });

    test('a refused limit-order create is not journaled', () async {
      final journal = InMemoryUnknownWriteJournal();
      final exchange = exchangeOver(
        FakeBbxHttp(
          body: const {
            'error': {'code': -1, 'message': 'no'},
          },
        ),
        journal,
      );

      final _ = await exchange.limitOrders.create(
        LimitOrderDraft(
          limitPrice: 90000,
          fiatAmount: 100,
          currency: FiatCurrency.cad,
          address: 'bc1qlimit',
        ),
      );

      expect(journal.entries, isEmpty);
    });

    test(
      'a default wallet save with an unknown outcome is journaled',
      () async {
        final journal = InMemoryUnknownWriteJournal();
        final exchange = exchangeForTesting(
          saveDefaultWallet: ({
            required walletType,
            required address,
            existingRecipientId,
          }) async => const WriteOutcomeUnknown('504'),
          unknownWrites: journal,
          readSessionPoint: () async =>
              const Ok((environment: ExchangeEnvironment.mainnet, epoch: 2)),
        );

        final write = await exchange.saveDefaultWallet(
          walletType: BtcNetwork.bitcoin,
          address: 'bc1qdefault',
        );

        expect(write, isA<WriteOutcomeUnknown<DefaultWallet>>());
        final entry = journal.entries.single.$1;
        expect(entry.kind, UnknownWriteKind.defaultWalletSave);
        expect(entry.environment, ExchangeEnvironment.mainnet);
        expect(entry.sessionEpoch, 2);
        expect(entry.request, {
          'walletType': 'bitcoin',
          'address': 'bc1qdefault',
        });
      },
    );

    test(
      'without a journal nothing is recorded and writes pass through',
      () async {
        final exchange = exchangeForTesting(
          saveDefaultWallet: ({
            required walletType,
            required address,
            existingRecipientId,
          }) async => const WriteOutcomeUnknown('504'),
        );

        expect(
          await exchange.saveDefaultWallet(
            walletType: BtcNetwork.bitcoin,
            address: 'bc1qdefault',
          ),
          isA<WriteOutcomeUnknown<DefaultWallet>>(),
        );
      },
    );
  });
}
