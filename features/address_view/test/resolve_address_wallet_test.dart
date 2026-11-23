import 'package:address_view/address_view.dart';
import 'package:address_view/src/domain/resolve_address_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart' show WalletKey;

class _Inventory extends Mock implements WalletInventory {}

void main() {
  test('does not query the inventory for an empty route parameter', () async {
    final inventory = _Inventory();
    final usecase = ResolveAddressWalletUsecase(inventory);

    expect(
      await usecase.execute(''),
      const Err<WalletKey, AddressViewFailure>(
        AddressViewWalletNotFoundFailure(),
      ),
    );
    verifyZeroInteractions(inventory);
  });

  test('separates a missing wallet from unavailable inventory', () async {
    final inventory = _Inventory();
    final usecase = ResolveAddressWalletUsecase(inventory);
    when(
      () => inventory.readWallet('missing'),
    ).thenAnswer((_) async => const Err(WalletRegistrationNotFoundFailure()));
    when(() => inventory.readWallet('locked'))
        .thenAnswer((_) async => const Err(UseSecretFailure('access locked')));

    expect(
      await usecase.execute('missing'),
      const Err<WalletKey, AddressViewFailure>(
        AddressViewWalletNotFoundFailure(),
      ),
    );
    expect(
      await usecase.execute('locked'),
      const Err<WalletKey, AddressViewFailure>(
        AddressViewAddressesUnavailableFailure(),
      ),
    );
  });
}
