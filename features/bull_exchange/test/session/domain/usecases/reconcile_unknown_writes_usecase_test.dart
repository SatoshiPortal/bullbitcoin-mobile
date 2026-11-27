import 'package:bull_exchange/src/session/domain/usecases/reconcile_unknown_writes_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 's',
);

void main() {
  test('without a journal there is nothing to settle', () async {
    final result = await ReconcileUnknownWritesUsecase(exchangeForTesting())
        .execute(_session);
    expect(
      (result as Ok<UnknownWriteReconciliation, Failure>).value,
      const UnknownWriteReconciliation(settled: 0, open: 0),
    );
  });

  test('a session that is no longer current settles nothing', () async {
    final result = await ReconcileUnknownWritesUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(
          const ExchangeAccessSignedIn(
            ExchangeSession(
              environment: ExchangeEnvironment.mainnet,
              epoch: 2,
              sessionId: 'later',
            ),
          ),
        ),
        unknownWrites: InMemoryUnknownWriteJournal(),
      ),
    ).execute(_session);
    expect(result, isA<Err<UnknownWriteReconciliation, Failure>>());
  });
}
