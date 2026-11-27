import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:exchange/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

/// What each session-bound operation does with a session that is no longer
/// the current one: it answers that the session changed and never acts on
/// the session signed in now.
const _current = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 3,
  sessionId: 'now',
);
const _old = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 2,
  sessionId: 'before',
);

ExchangeAccessLifecycle _signedIn() =>
    fixedAccessForTesting(const ExchangeAccessSignedIn(_current));

void main() {
  group('openUnknownWrites', () {
    Future<InMemoryUnknownWriteJournal> journalWithOneEntry() async {
      final journal = InMemoryUnknownWriteJournal();
      final _ = await journal.record(
        const UnknownWriteDraft(
          kind: UnknownWriteKind.buyConfirm,
          environment: ExchangeEnvironment.mainnet,
          orderId: 'o-1',
          request: {'orderId': 'o-1'},
        ),
      );
      return journal;
    }

    test('reads the journal of the current session', () async {
      final exchange = exchangeForTesting(
        access: _signedIn(),
        unknownWrites: await journalWithOneEntry(),
      );
      final open = await exchange.openUnknownWrites(_current);
      expect(
        open,
        isA<Ok<List<UnknownWrite>, Failure>>().having(
          (r) => r.value.single.orderId,
          'orderId',
          'o-1',
        ),
      );
    });

    test('an old session gets no entries of the current one', () async {
      final exchange = exchangeForTesting(
        access: _signedIn(),
        unknownWrites: await journalWithOneEntry(),
      );
      expect(
        await exchange.openUnknownWrites(_old),
        isA<Err<List<UnknownWrite>, Failure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeOperationStaleFailure>(),
        ),
      );
    });
  });

  group('getSessionUserSummary', () {
    test('reads the summary of the current session', () async {
      final asked = <ExchangeEnvironment?>[];
      final exchange = exchangeForTesting(
        access: _signedIn(),
        getUserSummary: (environment) async {
          asked.add(environment);
          return const Err(ExchangeAccountUnavailableFailure());
        },
      );
      final _ = await exchange.getSessionUserSummary(_current);
      expect(asked, [ExchangeEnvironment.mainnet]);
    });

    test('an old session reads nothing', () async {
      final exchange = exchangeForTesting(access: _signedIn());
      expect(
        await exchange.getSessionUserSummary(_old),
        isA<Err<UserSummary, ExchangeFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeOperationStaleFailure>(),
        ),
      );
    });
  });

  group('limit orders', () {
    // A client is opened only for the current session; an old one opens none.
    Exchange exchange(List<String> opened) => exchangeWithTransportForTesting(
      readSession: () async => const Ok((
        environment: ExchangeEnvironment.mainnet,
        epoch: 3,
        apiKey: 'k',
      )),
      openClient: (endpoint, _) {
        opened.add('$endpoint');
        throw StateError('no client in this test');
      },
      access: _signedIn(),
    );

    test('a read for an old session is refused before any client', () async {
      final opened = <String>[];
      final orders = exchange(opened).limitOrders;
      for (final read in [
        orders.listActive(_old),
        orders.listRecent(_old),
        orders.get(_old, 'lo-1'),
        orders.cancel(_old, 'lo-1'),
        orders.cancelAll(_old),
      ]) {
        expect(
          await read,
          isA<Err<Object, ExchangeFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<ExchangeOperationStaleFailure>(),
          ),
        );
      }
      expect(
        await orders.getRate(_old, 'CAD'),
        isA<Err<LimitOrderRate, ExchangeFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeOperationStaleFailure>(),
        ),
      );
      expect(opened, isEmpty);
    });

    test('a create for an old session is not sent', () async {
      final opened = <String>[];
      expect(
        await exchange(opened).limitOrders.create(
          _old,
          LimitOrderDraft(
            limitPrice: 90000,
            fiatAmount: 100,
            currency: FiatCurrency.cad,
            address: 'bc1qaddress',
          ),
        ),
        isA<WriteNotSent<LimitOrder>>().having(
          (w) => w.reason,
          'reason',
          ExchangeNotSentReason.sessionChanged,
        ),
      );
      expect(opened, isEmpty);
    });
  });

  group('reconcileUnknownWrites', () {
    test('an old session reconciles nothing', () async {
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
        access: _signedIn(),
        unknownWrites: journal,
      );
      expect(
        await exchange.reconcileUnknownWrites(_old),
        isA<Err<UnknownWriteReconciliation, Failure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeOperationStaleFailure>(),
        ),
      );
      expect(journal.entries, hasLength(1));
    });
  });
}
