import 'package:address_view/address_view.dart';
import 'package:preferences/preferences.dart';
import 'package:labels/labels.dart';
import 'package:receive/receive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockLabels extends Mock implements Labels {}

class _MockSettings extends Mock implements Preferences {}

Receive _receive(Labels labels) => Receive.open(
  addresses: _ReceiveAddressView(),
  labels: labels,
  preferences: _MockSettings(),
  readPrice: ({required network, required currency}) =>
      throw StateError('Unexpected price read'),
  readPrices: ({required network}) => throw StateError('Unexpected quote read'),
);

Label _addressLabel({int id = 1, required String label}) =>
    Label.addr(id: id, address: 'bc1qtest', label: label);

void main() {
  setUpAll(() {
    registerFallbackValue(NewLabel.addr(address: 'bc1qtest', label: 'x'));
  });

  group('loadAddressNote', () {
    test('returns the first user-authored label', () async {
      final labels = _MockLabels();
      when(() => labels.fetch(reference: 'bc1qtest'))
          .thenAnswer((_) async => Ok([_addressLabel(label: 'lunch money')]));

      final result = await _receive(labels).loadAddressNote('bc1qtest');

      expect(result, isA<Ok<String, ReceiveFailure>>());
      expect((result as Ok<String, ReceiveFailure>).value, 'lunch money');
    });

    test('skips system labels — they are not user notes and must never '
        'pre-fill the counterparty-visible message', () async {
      final labels = _MockLabels();
      when(() => labels.fetch(reference: 'bc1qtest')).thenAnswer(
        (_) async => Ok([_addressLabel(label: LabelSystem.payjoin.label)]),
      );

      final result = await _receive(labels).loadAddressNote('bc1qtest');

      expect((result as Ok<String, ReceiveFailure>).value, '');
    });

    test('uses an empty note when the label query fails', () async {
      final labels = _MockLabels();
      when(() => labels.fetch(reference: 'bc1qtest'))
          .thenAnswer((_) async => const Err(LabelUnexpectedFailure()));

      final result = await _receive(labels).loadAddressNote('bc1qtest');

      expect((result as Ok<String, ReceiveFailure>).value, isEmpty);
    });

    test('maps a thrown read into a sanitized failure', () async {
      final labels = _MockLabels();
      when(
        () => labels.fetch(reference: 'bc1qtest'),
      ).thenThrow(Exception('drift: database is locked at /data/app.sqlite'));

      final result = await _receive(labels).loadAddressNote('bc1qtest');

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

  group('saveAddressNote', () {
    test('stores a non-empty note', () async {
      final labels = _MockLabels();
      when(() => labels.store(any())).thenAnswer(
        (_) async => Ok<Label, LabelFailure>(_addressLabel(label: 'dinner')),
      );

      final result = await _receive(labels)
          .saveAddressNote(address: 'bc1qtest', walletId: 'w1', note: 'dinner');

      expect(result, isA<Ok<void, ReceiveFailure>>());
      verify(() => labels.store(any())).called(1);
      verifyNever(() => labels.trash(any()));
    });

    test('an empty note DELETES the address labels instead of storing an '
        'empty one, which would annotate the address with a blank note '
        'forever', () async {
      final labels = _MockLabels();
      when(
        () => labels.fetch(reference: 'bc1qtest'),
      ).thenAnswer((_) async => Ok([_addressLabel(id: 7, label: 'old note')]));
      when(() => labels.trash(7))
          .thenAnswer((_) async => const Ok<void, LabelFailure>(null));

      final result = await _receive(labels)
          .saveAddressNote(address: 'bc1qtest', walletId: 'w1', note: '');

      expect(result, isA<Ok<void, ReceiveFailure>>());
      verify(() => labels.trash(7)).called(1);
      verifyNever(() => labels.store(any()));
    });

    test('lifts a LabelFailure from a failed store into this feature\'s '
        'family, so the receive UI never translates a foreign type', () async {
      final labels = _MockLabels();
      when(() => labels.store(any())).thenAnswer(
        (_) async => const Err<Label, LabelFailure>(
          LabelUnexpectedFailure('drift: UNIQUE constraint failed'),
        ),
      );

      final result = await _receive(labels)
          .saveAddressNote(address: 'bc1qtest', walletId: 'w1', note: 'dinner');

      switch (result) {
        case Ok():
          fail('a failed store must not be reported as saved');
        case Err(:final failure):
          expect(failure, isA<ReceiveNoteNotSavedFailure>());
          expect(failure.logMessage, contains('UNIQUE constraint'));
      }
    });

    test('a failed lookup leaves no labels to delete', () async {
      final labels = _MockLabels();
      when(() => labels.fetch(reference: 'bc1qtest'))
          .thenAnswer((_) async => const Err(LabelUnexpectedFailure()));

      final result = await _receive(labels)
          .saveAddressNote(address: 'bc1qtest', walletId: 'w1', note: '');

      expect(result, isA<Ok<void, ReceiveFailure>>());
      verifyNever(() => labels.trash(any()));
      verifyNever(() => labels.store(any()));
    });

    test('reports a failed trash rather than silently keeping the old '
        'note', () async {
      final labels = _MockLabels();
      when(
        () => labels.fetch(reference: 'bc1qtest'),
      ).thenAnswer((_) async => Ok([_addressLabel(id: 7, label: 'old note')]));
      when(() => labels.trash(7)).thenAnswer(
        (_) async => const Err<void, LabelFailure>(LabelUnexpectedFailure()),
      );

      final result = await _receive(labels)
          .saveAddressNote(address: 'bc1qtest', walletId: 'w1', note: '');

      expect(result, isA<Err<void, ReceiveFailure>>());
    });
  });
  group('addressNoteSuggestions', () {
    test('converts a throw into a sanitized failure', () async {
      final labels = _MockLabels();
      when(() => labels.suggestions(type: any(named: 'type')))
          .thenThrow(Exception('drift: no such table labels'));

      final result = await _receive(labels).addressNoteSuggestions();

      switch (result) {
        case Ok():
          fail('a throw must not be reported as suggestions');
        case Err(:final failure):
          expect(failure, isA<ReceiveUnexpectedFailure>());
          expect(failure.logMessage, contains('no such table'));
      }
    });

    test('uses no suggestions when the address label query fails', () async {
      final labels = _MockLabels();
      when(() => labels.suggestions(type: LabelType.address))
          .thenAnswer((_) async => const Err(LabelUnexpectedFailure()));

      final result = await _receive(labels).addressNoteSuggestions();

      expect((result as Ok<Set<String>, ReceiveFailure>).value, isEmpty);
    });

    test('scopes suggestions to address labels — a transaction label is '
        'private and must never become a BIP21 message=', () async {
      final labels = _MockLabels();
      when(() => labels.suggestions(type: any(named: 'type')))
          .thenAnswer((_) async => Ok({'lunch'}));

      final result = await _receive(labels).addressNoteSuggestions();
      expect(result, isA<Ok<Set<String>, ReceiveFailure>>());

      verify(() => labels.suggestions(type: LabelType.address)).called(1);
    });
  });
}

class _ReceiveAddressView extends Mock implements AddressView {}
