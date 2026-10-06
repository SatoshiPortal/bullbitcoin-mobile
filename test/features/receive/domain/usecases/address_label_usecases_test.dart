import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bb_mobile/features/receive/domain/usecases/load_receive_address_label_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/save_receive_address_label_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockLabelsFacade extends Mock implements LabelsFacade {}

Label _addressLabel({int id = 1, required String label}) =>
    Label.addr(id: id, address: 'bc1qtest', label: label);

void main() {
  setUpAll(() {
    registerFallbackValue(NewLabel.addr(address: 'bc1qtest', label: 'x'));
  });

  group('LoadReceiveAddressLabelUsecase', () {
    test('returns the first user-authored label', () async {
      final labels = _MockLabelsFacade();
      when(
        () => labels.fetchByReference('bc1qtest'),
      ).thenAnswer((_) async => [_addressLabel(label: 'lunch money')]);

      final result = await LoadReceiveAddressLabelUsecase(
        labels,
      ).execute('bc1qtest');

      expect(result, isA<Ok<String, ReceiveFailure>>());
      expect((result as Ok<String, ReceiveFailure>).value, 'lunch money');
    });

    test('skips system labels — they are not user notes and must never '
        'pre-fill the counterparty-visible message', () async {
      final labels = _MockLabelsFacade();
      when(() => labels.fetchByReference('bc1qtest')).thenAnswer(
        (_) async => [_addressLabel(label: LabelSystem.payjoin.label)],
      );

      final result = await LoadReceiveAddressLabelUsecase(
        labels,
      ).execute('bc1qtest');

      expect((result as Ok<String, ReceiveFailure>).value, '');
    });

    test('maps a thrown read into a sanitized failure', () async {
      final labels = _MockLabelsFacade();
      when(
        () => labels.fetchByReference('bc1qtest'),
      ).thenThrow(Exception('drift: database is locked at /data/app.sqlite'));

      final result = await LoadReceiveAddressLabelUsecase(
        labels,
      ).execute('bc1qtest');

      switch (result) {
        case Ok():
          fail('a thrown read must not be reported as a label');
        case Err(:final failure):
          // A failed READ is not a failed save: the note-not-saved copy would
          // be wrong here, so this maps to the catch-all.
          expect(failure, isA<ReceiveUnexpectedFailure>());
          expect(failure.logMessage, contains('app.sqlite'));
      }
    });
  });

  group('SaveReceiveAddressLabelUsecase', () {
    test('stores a non-empty note', () async {
      final labels = _MockLabelsFacade();
      when(() => labels.store(any())).thenAnswer(
        (_) async => Ok<Label, LabelFailure>(_addressLabel(label: 'dinner')),
      );

      final result = await SaveReceiveAddressLabelUsecase(
        labels,
      ).execute(address: 'bc1qtest', walletId: 'w1', note: 'dinner');

      expect(result, isA<Ok<void, ReceiveFailure>>());
      verify(() => labels.store(any())).called(1);
      verifyNever(() => labels.trash(any()));
    });

    test('an empty note DELETES the address labels instead of storing an '
        'empty one, which would annotate the address with a blank note '
        'forever', () async {
      final labels = _MockLabelsFacade();
      when(
        () => labels.fetchByReference('bc1qtest'),
      ).thenAnswer((_) async => [_addressLabel(id: 7, label: 'old note')]);
      when(
        () => labels.trash(7),
      ).thenAnswer((_) async => const Ok<Null, LabelFailure>(null));

      final result = await SaveReceiveAddressLabelUsecase(
        labels,
      ).execute(address: 'bc1qtest', walletId: 'w1', note: '');

      expect(result, isA<Ok<void, ReceiveFailure>>());
      verify(() => labels.trash(7)).called(1);
      verifyNever(() => labels.store(any()));
    });

    test('lifts a LabelFailure from a failed store into this feature\'s '
        'family, so the receive UI never translates a foreign type', () async {
      final labels = _MockLabelsFacade();
      when(() => labels.store(any())).thenAnswer(
        (_) async => const Err<Label, LabelFailure>(
          LabelUnexpectedFailure('drift: UNIQUE constraint failed'),
        ),
      );

      final result = await SaveReceiveAddressLabelUsecase(
        labels,
      ).execute(address: 'bc1qtest', walletId: 'w1', note: 'dinner');

      switch (result) {
        case Ok():
          fail('a failed store must not be reported as saved');
        case Err(:final failure):
          expect(failure, isA<ReceiveNoteNotSavedFailure>());
          expect(failure.logMessage, contains('UNIQUE constraint'));
      }
    });

    test('reports a failed trash rather than silently keeping the old '
        'note', () async {
      final labels = _MockLabelsFacade();
      when(
        () => labels.fetchByReference('bc1qtest'),
      ).thenAnswer((_) async => [_addressLabel(id: 7, label: 'old note')]);
      when(() => labels.trash(7)).thenAnswer(
        (_) async => const Err<Null, LabelFailure>(LabelUnexpectedFailure()),
      );

      final result = await SaveReceiveAddressLabelUsecase(
        labels,
      ).execute(address: 'bc1qtest', walletId: 'w1', note: '');

      expect(result, isA<Err<void, ReceiveFailure>>());
    });
  });
}
