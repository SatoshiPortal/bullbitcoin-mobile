import 'package:bull_exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

class _Inventory extends Mock implements WalletInventory {}

class _Native extends Mock implements WalletNativeLifecycle {}

void main() {
  final wallet = walletRegistrationForTesting(
    id: 'payout-wallet',
    network: BitcoinNetwork.mainnet,
  );
  final key = WalletKey(id: wallet.id, network: wallet.network);
  late _Inventory inventory;
  late _Native native;
  late ResolveWalletAddressUsecase usecase;

  setUp(() {
    inventory = _Inventory();
    native = _Native();
    usecase = ResolveWalletAddressUsecase(
      ExchangePayoutWallets(inventory, native),
    );
  });

  test(
    'only requests the current receive address for an admitted wallet',
    () async {
      when(() => inventory.readWallet(wallet.id))
          .thenAnswer((_) async => Ok(wallet));
      when(() => native.receive(key, advance: false))
          .thenAnswer((_) async => const Err(SyncNotFoundFailure()));

      expect(await usecase.execute(wallet), isA<Err>());
      verify(() => native.receive(key, advance: false)).called(1);
      verifyNoMoreInteractions(native);
    },
  );

  test(
    'does not request an address after inventory admission is revoked',
    () async {
      when(
        () => inventory.readWallet(wallet.id),
      ).thenAnswer((_) async => const Err(WalletRegistrationNotFoundFailure()));

      expect(await usecase.execute(wallet), isA<Err>());
      verifyZeroInteractions(native);
    },
  );
}
