import 'dart:io';

import 'package:address_view/address_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labels/labels.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show SecretFailure;
import 'package:secrets/storage.dart' show RegisteredWallet;
import 'package:secrets/testing.dart' show FakeSecureStoragePlatform;
import 'package:sync/sync.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;

import '../../../support/inventory_fixture.dart';

class _Labels extends Mock implements Labels {}

class _Native extends Mock implements WalletNativeLifecycle {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses the admitted concrete network and keeps a resolved address without labels', () async {
    FakeSecureStoragePlatform().install();
    final directory = await Directory.systemTemp.createTemp('indexed-address');
    addTearDown(() => directory.delete(recursive: true));
    final fixture = await InventoryFixture.open(directory);
    addTearDown(fixture.close);

    const id = 'wpkh([01234567/84h/1h/0h]):regtest';
    const address = 'indexed-receive-address';
    expect(
      await fixture.inventory.registerWallet(
        const RegisteredWallet(
          id: id,
          secretFingerprint: null,
          masterFingerprint: '',
          signer: 'none',
          network: 'bitcoinRegtest',
          xpub: 'public-key-marker',
          externalDescriptor: "wpkh([01234567/84'/1'/7']public-key-marker/0/*)",
          internalDescriptor: 'wpkh(public-key-marker/1/*)',
          label: '',
          birthday: null,
          isDefault: false,
        ),
      ),
      isA<Ok<void, SecretFailure>>(),
    );
    final expected = WalletKey(id: id, network: BitcoinNetwork.regtest);
    final wallet = await testWallet(
      key: expected,
      addresses: AddressBook(
        receiveIndex: 0,
        changeIndex: -1,
        receive: const [
          DerivedAddress(
            keychain: Keychain.external,
            index: 0,
            address: address,
          ),
        ],
        change: [],
      ),
    );
    final labels = _Labels();
    when(() => labels.fetch(reference: address))
        .thenAnswer((_) async => const Err(LabelUnexpectedFailure()));
    final keys = <WalletKey>[];
    final addresses = AddressView.open(
      labels: labels,
      inventory: fixture.inventory,
      native: _Native(),
      loadWallet: (key) async {
        keys.add(key);
        return Ok(wallet);
      },
    );

    final result = await addresses.at(walletId: id, index: 0);
    expect(
      result,
      isA<Ok<WalletAddress, AddressViewFailure>>()
          .having((result) => result.value.address, 'address', address)
          .having((result) => result.value.labels, 'labels', isEmpty),
    );
    expect(keys, [expected]);
    verify(() => labels.fetch(reference: address)).called(1);
  });
}
