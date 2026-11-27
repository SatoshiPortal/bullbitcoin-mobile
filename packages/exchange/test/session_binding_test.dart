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
}
