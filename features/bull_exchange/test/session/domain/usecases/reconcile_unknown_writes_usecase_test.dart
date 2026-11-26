import 'package:bull_exchange/src/session/domain/usecases/reconcile_unknown_writes_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('without a journal there is nothing to settle', () async {
    final result = await ReconcileUnknownWritesUsecase(exchangeForTesting())
        .execute();
    expect(
      (result as Ok<UnknownWriteReconciliation, Failure>).value,
      const UnknownWriteReconciliation(settled: 0, open: 0),
    );
  });

  test('an unreadable session point settles nothing', () async {
    final result = await ReconcileUnknownWritesUsecase(
      exchangeForTesting(
        unknownWrites: InMemoryUnknownWriteJournal(),
        readSessionPoint: () async =>
            const Err(ExchangeNotAuthenticatedFailure()),
      ),
    ).execute();
    expect(result, isA<Err<UnknownWriteReconciliation, Failure>>());
  });
}
