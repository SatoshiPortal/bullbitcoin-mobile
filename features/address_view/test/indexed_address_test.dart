import 'package:address_view/address_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labels/labels.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;

class _Inventory extends Mock implements WalletInventory {}

class _Labels extends Mock implements Labels {}

class _Native extends Mock implements WalletNativeLifecycle {}

void main() {
  test('an indexed read cannot bypass inventory admission', () async {
    final inventory = _Inventory();
    final labels = _Labels();
    when(
      () => inventory.readWallet('missing'),
    ).thenAnswer((_) async => const Err(WalletRegistrationNotFoundFailure()));
    when(() => inventory.readWallet('locked'))
        .thenAnswer((_) async => const Err(UseSecretFailure('access locked')));
    final addresses = AddressView.open(
      labels: labels,
      inventory: inventory,
      native: _Native(),
      loadWallet: (_) async => throw StateError('Unadmitted Sync read'),
    );

    expect(
      await addresses.at(walletId: 'missing', index: 0),
      isA<Err<WalletAddress, AddressViewFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<AddressViewWalletNotFoundFailure>(),
      ),
    );
    expect(
      await addresses.at(walletId: 'locked', index: 0),
      isA<Err<WalletAddress, AddressViewFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<AddressViewAddressesUnavailableFailure>(),
      ),
    );
    verify(() => inventory.readWallet('missing')).called(1);
    verify(() => inventory.readWallet('locked')).called(1);
    verifyZeroInteractions(labels);
  });

  test('a negative index cannot reach inventory or Sync', () async {
    final inventory = _Inventory();
    final labels = _Labels();
    final addresses = AddressView.open(
      labels: labels,
      inventory: inventory,
      native: _Native(),
      loadWallet: (_) async => throw StateError('Unexpected Sync read'),
    );

    expect(
      await addresses.at(walletId: 'wallet', index: -1),
      isA<Err<WalletAddress, AddressViewFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<AddressViewAddressesUnavailableFailure>(),
      ),
    );
    verifyZeroInteractions(inventory);
    verifyZeroInteractions(labels);
  });
}
