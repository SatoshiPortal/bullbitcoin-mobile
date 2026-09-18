import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/transactions/application/usecases/delete_transaction_note_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_note_suggestions_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/save_transaction_note_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _FakeNewLabel extends Fake implements NewLabel {}

/// These three exist so no transactions-layer code holds a `LabelFailure`: the
/// labels feature is another feature, and its failure type is not part of this
/// feature's contract.
void main() {
  late _MockLabelsFacade labels;

  setUpAll(() => registerFallbackValue(_FakeNewLabel()));

  setUp(() => labels = _MockLabelsFacade());

  group('SaveTransactionNoteUsecase', () {
    test('returns the stored label on success', () async {
      final stored = Label.tx(id: 1, transactionId: 'tx-1', label: 'coffee');
      when(
        () => labels.store(any()),
      ).thenAnswer((_) async => Ok<Label, LabelFailure>(stored));

      final result = await SaveTransactionNoteUsecase(
        labels,
      ).execute(transactionId: 'tx-1', label: 'coffee', origin: 'w1');

      expect((result as Ok).value, stored);
    });

    test('translates a LabelFailure into the transaction family', () async {
      when(() => labels.store(any())).thenAnswer(
        (_) async => const Err<Label, LabelFailure>(
          LabelUnexpectedFailure('UNIQUE constraint failed: labels.reference'),
        ),
      );

      final result = await SaveTransactionNoteUsecase(
        labels,
      ).execute(transactionId: 'tx-1', label: 'coffee', origin: 'w1');

      final failure = (result as Err).failure;
      expect(failure, isA<TransactionUnexpectedFailure>());
      expect(failure, isNot(isA<LabelFailure>()));
      expect(failure.logMessage, isNot(contains('UNIQUE constraint')));
    });
  });

  group('DeleteTransactionNoteUsecase', () {
    test('returns Ok when the note is trashed', () async {
      when(
        () => labels.trash(1),
      ).thenAnswer((_) async => const Ok<Null, LabelFailure>(null));

      expect(
        await DeleteTransactionNoteUsecase(labels).execute(1),
        isA<Ok<Null, TransactionFailure>>(),
      );
    });

    test('translates a LabelFailure into the transaction family', () async {
      when(() => labels.trash(1)).thenAnswer(
        (_) async => const Err<Null, LabelFailure>(
          LabelUnexpectedFailure('database is locked'),
        ),
      );

      final result = await DeleteTransactionNoteUsecase(labels).execute(1);

      final failure = (result as Err).failure;
      expect(failure, isA<TransactionUnexpectedFailure>());
      expect(failure, isNot(isA<LabelFailure>()));
      expect(failure.logMessage, isNot(contains('database is locked')));
    });
  });

  group('GetTransactionNoteSuggestionsUsecase', () {
    test('returns the distinct labels', () async {
      when(
        () => labels.fetchDistinctLabels(),
      ).thenAnswer((_) async => {'coffee', 'rent'});

      expect(await GetTransactionNoteSuggestionsUsecase(labels).execute(), {
        'coffee',
        'rent',
      });
    });

    test('degrades to no suggestions rather than failing the screen', () async {
      when(
        () => labels.fetchDistinctLabels(),
      ).thenThrow(StateError('database is locked'));

      expect(
        await GetTransactionNoteSuggestionsUsecase(labels).execute(),
        isEmpty,
      );
    });
  });
}
