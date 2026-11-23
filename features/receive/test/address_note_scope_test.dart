import 'package:address_view/address_view.dart';
import 'package:labels/labels.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:receive/receive.dart';
import 'package:flutter_test/flutter_test.dart';

class _Labels extends Mock implements Labels {}

class _Preferences extends Mock implements Preferences {}

void main() {
  test(
    'clearing a note only deletes address labels, regardless of origin',
    () async {
      const address = 'bc1qtest';
      final labels = _Labels();
      when(() => labels.fetch(reference: address)).thenAnswer(
        (_) async => Ok([
          Label.addr(
            id: 1,
            address: address,
            label: 'Old note',
            origin: 'other-wallet',
          ),
          Label.addr(id: 2, address: address, label: LabelSystem.payjoin.label),
          Label.tx(id: 3, transactionId: address, label: 'Private note'),
        ]),
      );
      when(() => labels.trash(any())).thenAnswer((_) async => const Ok(null));
      final receive = Receive.open(
        addresses: _ReceiveAddressView(),
        labels: labels,
        preferences: _Preferences(),
        readPrice: ({required network, required currency}) =>
            throw StateError('Unexpected price read'),
        readPrices: ({required network}) =>
            throw StateError('Unexpected quote read'),
      );

      expect(
        await receive.saveAddressNote(
          address: address,
          walletId: 'current-wallet',
          note: '',
        ),
        isA<Ok<void, ReceiveFailure>>(),
      );
      verifyInOrder([
        () => labels.fetch(reference: address),
        () => labels.trash(1),
        () => labels.trash(2),
      ]);
      verifyNoMoreInteractions(labels);
    },
  );
}

class _ReceiveAddressView extends Mock implements AddressView {}
