import 'package:bb_mobile/features/address_view/domain/wallet_address.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/next_unused_receive_address_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

class _Receive extends Mock implements GetReceiveAddressUsecase {}

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
    when(() => receive.execute(walletId: 'wallet', generateNew: true))
        .thenAnswer((_) async {
          addresses.moveNext();
          return addresses.current;
        });
    final result = await NextUnusedReceiveAddressUsecase(receive)
        .execute('wallet', excludedAddresses: {'selected'});
    expect(result, isA<Ok<String, WalletFailure>>());
    expect((result as Ok<String, WalletFailure>).value, 'fresh');
    verify(() => receive.execute(walletId: 'wallet', generateNew: true))
        .called(3);
  });

  test('bounds repeated duplicate responses from the writer', () async {
    final receive = _Receive();
    when(() => receive.execute(walletId: 'wallet', generateNew: true))
        .thenAnswer((_) async => _address('selected'));
    final result = await NextUnusedReceiveAddressUsecase(receive)
        .execute('wallet', excludedAddresses: {'selected'});
    expect(result, isA<Err<String, WalletFailure>>());
    verify(() => receive.execute(walletId: 'wallet', generateNew: true))
        .called(20);
  });

  test('maps an unavailable writer to a typed failure', () async {
    final receive = _Receive();
    when(() => receive.execute(walletId: 'wallet', generateNew: true))
        .thenThrow(GetReceiveAddressException('storage'));
    final result = await NextUnusedReceiveAddressUsecase(receive)
        .execute('wallet');
    expect(result, isA<Err<String, WalletFailure>>());
  });
}
