import 'package:bb_mobile/features/address_view/domain/wallet_address.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_transfer_receive_address_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_discovery_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Receive extends Mock implements GetReceiveAddressUsecase {}

void main() {
  test(
    'returns the selected wallet address and maps storage exceptions',
    () async {
      final receive = _Receive();
      final reader = GetTransferReceiveAddressUsecase(receive);
      when(() => receive.execute(walletId: 'selected')).thenAnswer(
        (_) async => WalletAddress(
          walletId: 'selected',
          index: 0,
          address: 'bcrt1publicfixture',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      expect(
        await reader.execute('selected'),
        isA<Ok<String, WalletDiscoveryFailure>>().having(
          (result) => result.value,
          'selected address',
          'bcrt1publicfixture',
        ),
      );
      when(() => receive.execute(walletId: 'selected'))
          .thenThrow(Exception('private storage detail'));
      expect(
        await reader.execute('selected'),
        isA<Err<String, WalletDiscoveryFailure>>(),
      );
    },
  );

  test(
    'programmer errors are not converted into recoverable failures',
    () async {
      final receive = _Receive();
      when(() => receive.execute(walletId: 'selected'))
          .thenThrow(StateError('programmer error'));
      expect(
        GetTransferReceiveAddressUsecase(receive).execute('selected'),
        throwsStateError,
      );
    },
  );
}
