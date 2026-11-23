import 'package:address_view/address_view.dart';
import 'package:labels/labels.dart';
import 'package:preferences/preferences.dart';
import 'package:receive/receive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Receive extends Mock implements AddressView {}

void main() {
  test(
    'returns the selected wallet address and maps typed storage failures',
    () async {
      final receive = _Receive();
      final reader = _open(receive);
      when(() => receive.receiveAddress(walletId: 'selected')).thenAnswer(
        (_) async => Ok(
          WalletAddress(
            walletId: 'selected',
            index: 0,
            address: 'bcrt1publicfixture',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ),
      );
      expect(
        await reader.transferAddress('selected'),
        isA<Ok<String, ReceiveFailure>>().having(
          (result) => result.value,
          'selected address',
          'bcrt1publicfixture',
        ),
      );
      when(() => receive.receiveAddress(walletId: 'selected')).thenAnswer(
        (_) async => const Err(AddressViewAddressesUnavailableFailure()),
      );
      expect(
        await reader.transferAddress('selected'),
        isA<Err<String, ReceiveFailure>>(),
      );
    },
  );

  test(
    'programmer errors are not converted into recoverable failures',
    () async {
      final receive = _Receive();
      when(() => receive.receiveAddress(walletId: 'selected'))
          .thenThrow(StateError('programmer error'));
      expect(_open(receive).transferAddress('selected'), throwsStateError);
    },
  );
}

class _Labels extends Mock implements Labels {}

class _Preferences extends Mock implements Preferences {}

Receive _open(AddressView addresses) => Receive.open(
  addresses: addresses,
  labels: _Labels(),
  preferences: _Preferences(),
  readPrice: ({required network, required currency}) =>
      throw StateError('Unexpected price read'),
  readPrices: ({required network}) => throw StateError('Unexpected quote read'),
);
