import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/transactions/application/ports/transaction_export_saver.dart';
import 'package:bb_mobile/features/transactions/application/usecases/export_transactions_csv_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/export/export_transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/export/export_transactions_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExportTransactionsCsvUsecase extends Mock
    implements ExportTransactionsCsvUsecase {}

class _MockTransactionExportSaver extends Mock
    implements TransactionExportSaver {}

void main() {
  late _MockExportTransactionsCsvUsecase exportCsvUsecase;
  late _MockTransactionExportSaver saver;

  ExportTransactionsCubit buildCubit() => ExportTransactionsCubit(
    exportTransactionsCsvUsecase: exportCsvUsecase,
    saver: saver,
  );

  setUp(() {
    exportCsvUsecase = _MockExportTransactionsCsvUsecase();
    saver = _MockTransactionExportSaver();
  });

  test('carries the failure so the screen never sticks on loading', () async {
    when(
      () => exportCsvUsecase.execute(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer(
      (_) async => const Err<String, TransactionFailure>(
        TransactionExportEmptyFailure(),
      ),
    );

    final cubit = buildCubit();
    addTearDown(cubit.close);
    await cubit.exportCsv();

    expect(
      cubit.state,
      isA<ExportTransactionsState>().having(
        (s) => s.mapOrNull(failure: (f) => f.failure),
        'failure',
        isA<TransactionExportEmptyFailure>(),
      ),
    );
  });

  test('a cancelled save returns to the idle form, not a failure', () async {
    when(
      () => exportCsvUsecase.execute(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => const Ok<String, TransactionFailure>('csv'));
    when(
      () => saver.save(any()),
    ).thenAnswer((_) async => const Ok<bool, TransactionFailure>(false));

    final cubit = buildCubit();
    addTearDown(cubit.close);
    await cubit.exportCsv();

    expect(cubit.state, const ExportTransactionsState.initial());
  });

  test('does not emit when the screen closes during the file picker', () async {
    // The native picker routinely outlives the screen that opened it: the user
    // can leave the export before choosing a destination. Emitting on a closed
    // cubit throws a StateError.
    when(
      () => exportCsvUsecase.execute(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => const Ok<String, TransactionFailure>('csv'));

    final picker = Completer<Result<bool, TransactionFailure>>();
    when(() => saver.save(any())).thenAnswer((_) => picker.future);

    final cubit = buildCubit();
    final exporting = cubit.exportCsv();

    await pumpEventQueue();
    await cubit.close();
    picker.complete(const Ok(true));

    await expectLater(exporting, completes);
  });
}
