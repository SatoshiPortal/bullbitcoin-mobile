import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/journaling_orders_repository.dart';
import 'package:exchange/src/data/journaling_recipients_repository.dart';
import 'package:exchange/testing.dart';
import 'package:mocktail/mocktail.dart' show Fake;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'bbx_api_test_http.dart';

final class _Orders extends Fake implements OrdersRepository {
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
  }) async => _write();
}

final class _Recipients extends Fake implements RecipientsRepository {
  final Result<Recipient, RecipientsFailure> answer;
  final saved = <RecipientDetails>[];

  _Recipients(this.answer);

  @override
  Future<Result<Recipient, RecipientsFailure>> saveRecipient(
    RecipientDetails details, {
    bool isFiatRecipient = true,
    required bool isTestnet,
  }) async {
    saved.add(details);
    return answer;
  }
}

typedef _Call = Future<ExchangeWrite<Object?>> Function(OrdersRepository);

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

const _limitSession = ExchangeSession(
  environment: ExchangeEnvironment.testnet,
  epoch: 7,
  sessionId: 'limit',
);

void main() {
  JournalingOrdersRepository journaling(
    OrdersRepository orders,
    UnknownWriteJournal journal,
  ) => JournalingOrdersRepository(
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

  group('recipient create', () {
    final details = InteracEmailCadDetails.create(
      email: 'sat@example.com',
      name: 'Satoshi',
      securityQuestion: 'colour?',
      securityAnswer: 'orange',
    );

    JournalingRecipientsRepository journaling(
      _Recipients recipients,
      UnknownWriteJournal journal,
    ) => JournalingRecipientsRepository(
      recipients,
      UnknownWriteRecorder(journal),
      readEpoch: (environment) async =>
          environment == ExchangeEnvironment.mainnet ? 5 : null,
    );

    test('an unknown outcome is journaled with the identity sent', () async {
      final journal = InMemoryUnknownWriteJournal();
      final inner = _Recipients(
        const Err(RecipientsSaveOutcomeUnknownFailure('504')),
      );

      final result = await journaling(
        inner,
        journal,
      ).saveRecipient(details, isTestnet: false);

      expect(
        result,
        isA<Err<Recipient, RecipientsFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<RecipientsSaveOutcomeUnknownFailure>(),
        ),
      );
      expect(inner.saved, [details]);
      final (entry, settlement) = journal.entries.single;
      expect(settlement, isNull);
      expect(entry.kind, UnknownWriteKind.recipientCreate);
      expect(entry.environment, ExchangeEnvironment.mainnet);
      expect(entry.sessionEpoch, 5);
      expect(entry.request, {
        'type': 'interacEmailCad',
        'email': 'sat@example.com',
      });
      final values = entry.request.values.join(' ');
      expect(values, isNot(contains('orange')));
      expect(values, isNot(contains('colour')));
    });

    for (final answer in <Result<Recipient, RecipientsFailure>>[
      const Err(RecipientsSaveFailure()),
      const Err(RecipientsNetworkFailure()),
      const Err(RecipientsNotAuthenticatedFailure()),
    ]) {
      test('${answer.runtimeType} is not journaled', () async {
        final journal = InMemoryUnknownWriteJournal();

        final _ = await journaling(
          _Recipients(answer),
          journal,
        ).saveRecipient(details, isTestnet: true);

        expect(journal.entries, isEmpty);
      });
    }

    test(
      'Exchange journals a recipient create when it has a journal',
      () async {
        final journal = InMemoryUnknownWriteJournal();
        final exchange = exchangeForTesting(
          recipients: _Recipients(
            const Err(RecipientsSaveOutcomeUnknownFailure('timeout')),
          ),
          unknownWrites: journal,
          readSessionPoint: () async =>
              const Ok((environment: ExchangeEnvironment.testnet, epoch: 3)),
        );

        final _ = await exchange.recipients.saveRecipient(
          details,
          isTestnet: true,
        );

        expect(
          journal.entries.single.$1.kind,
          UnknownWriteKind.recipientCreate,
        );
        expect(journal.entries.single.$1.sessionEpoch, 3);
      },
    );
  });

  group('preference save', () {
    Exchange exchangeAnswering(
      Result<void, ExchangeFailure> answer,
      UnknownWriteJournal? journal,
    ) => exchangeForTesting(
      saveUserPreference: (
        _, {
        language,
        currency,
        dcaEnabled,
        autoBuyEnabled,
        emailNotificationsEnabled,
      }) async => answer,
      unknownWrites: journal,
      readSessionPoint: () async =>
          const Ok((environment: ExchangeEnvironment.mainnet, epoch: 8)),
    );

    test('an unknown outcome is journaled with the fields sent', () async {
      final journal = InMemoryUnknownWriteJournal();

      final result =
          await exchangeAnswering(
            const Err(ExchangePreferencesSaveOutcomeUnknownFailure('504')),
            journal,
          ).saveUserPreference(
            ExchangeEnvironment.mainnet,
            currency: 'EUR',
            dcaEnabled: false,
          );

      expect(result, isA<Err<void, ExchangeFailure>>());
      final entry = journal.entries.single.$1;
      expect(entry.kind, UnknownWriteKind.preferencesSave);
      expect(entry.environment, ExchangeEnvironment.mainnet);
      expect(entry.sessionEpoch, 8);
      expect(entry.request, {'currency': 'EUR', 'dcaEnabled': 'false'});
    });

    for (final answer in <Result<void, ExchangeFailure>>[
      const Ok(null),
      const Err(ExchangePreferencesSaveFailure()),
      const Err(ExchangeNetworkFailure()),
      const Err(ExchangeNotAuthenticatedFailure()),
    ]) {
      test('$answer is not journaled', () async {
        final journal = InMemoryUnknownWriteJournal();

        final _ = await exchangeAnswering(
          answer,
          journal,
        ).saveUserPreference(ExchangeEnvironment.mainnet, language: 'fr');

        expect(journal.entries, isEmpty);
      });
    }

    test('another environment journals no epoch', () async {
      final journal = InMemoryUnknownWriteJournal();

      final _ = await exchangeAnswering(
        const Err(ExchangePreferencesSaveOutcomeUnknownFailure()),
        journal,
      ).saveUserPreference(ExchangeEnvironment.testnet, language: 'fr');

      expect(journal.entries.single.$1.sessionEpoch, isNull);
    });

    test('without a journal the answer passes through', () async {
      expect(
        await exchangeAnswering(
          const Err(ExchangePreferencesSaveOutcomeUnknownFailure()),
          null,
        ).saveUserPreference(ExchangeEnvironment.mainnet, language: 'fr'),
        isA<Err<void, ExchangeFailure>>(),
      );
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
          access: fixedAccessForTesting(
            const ExchangeAccessSignedIn(_limitSession),
          ),
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
        _limitSession,
        LimitOrderDraft(
          limitPrice: 90000,
          fiatAmount: 100,
          currency: FiatCurrency.cad,
          address: 'bc1qlimit',
        ),
      );

      expect(result, isA<WriteOutcomeUnknown<LimitOrder>>());
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
        _limitSession,
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

  group('order create', () {
    const session = ExchangeSession(
      environment: ExchangeEnvironment.mainnet,
      epoch: 4,
      sessionId: 's',
    );
    const request = OrderCreateJournalRequest(
      type: OrderType.sell,
      amount: BitcoinAmount(0.002),
      currency: FiatCurrency.eur,
    );

    test('an unknown create is journaled with what was sent', () async {
      final journal = InMemoryUnknownWriteJournal();

      await exchangeForTesting(unknownWrites: journal)
          .journalUnknownOrderCreate(session, request);

      final entry = journal.entries.single.$1;
      expect(entry.kind, UnknownWriteKind.orderCreate);
      expect(entry.environment, ExchangeEnvironment.mainnet);
      expect(entry.sessionEpoch, 4);
      expect(entry.orderId, isNull);
      expect(entry.request, request.toRequest());
    });

    test('without a journal nothing happens', () async {
      await exchangeForTesting().journalUnknownOrderCreate(session, request);
    });
  });
}
