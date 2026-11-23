import 'package:address_view/address_view.dart';
import 'package:labels/labels.dart';
import 'package:preferences/preferences.dart';
import 'package:receive/receive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

class _Receive extends Mock implements AddressView {}

WalletAddress _address(String value, {bool used = false}) => WalletAddress(
  walletId: 'wallet',
  index: 0,
  address: value,
  nrOfTransactions: used ? 1 : 0,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('advances past used and already selected receive addresses', () async {
    final receive = _Receive();
    final addresses = [
      _address('used', used: true),
      _address('selected'),
      _address('fresh'),
    ].iterator;
    when(() => receive.receiveAddress(walletId: 'wallet', advance: true))
        .thenAnswer((_) async {
          addresses.moveNext();
          return Ok(addresses.current);
        });
    final result = await _open(receive)
        .nextUnusedAddress('wallet', excludedAddresses: {'selected'});
    expect(result, isA<Ok<String, ReceiveFailure>>());
    expect((result as Ok<String, ReceiveFailure>).value, 'fresh');
    verify(() => receive.receiveAddress(walletId: 'wallet', advance: true))
        .called(3);
  });

  test('bounds repeated duplicate responses from the writer', () async {
    final receive = _Receive();
    when(() => receive.receiveAddress(walletId: 'wallet', advance: true))
        .thenAnswer((_) async => Ok(_address('selected')));
    final result = await _open(receive)
        .nextUnusedAddress('wallet', excludedAddresses: {'selected'});
    expect(result, isA<Err<String, ReceiveFailure>>());
    verify(() => receive.receiveAddress(walletId: 'wallet', advance: true))
        .called(20);
  });

  test('maps an unavailable writer to a typed failure', () async {
    final receive = _Receive();
    when(() => receive.receiveAddress(walletId: 'wallet', advance: true))
        .thenAnswer(
          (_) async => const Err(AddressViewAddressesUnavailableFailure()),
        );
    final result = await _open(receive).nextUnusedAddress('wallet');
    expect(result, isA<Err<String, ReceiveFailure>>());
  });
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
