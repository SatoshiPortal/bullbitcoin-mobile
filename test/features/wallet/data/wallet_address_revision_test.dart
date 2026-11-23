import 'dart:io';

import 'package:address_view/address_view.dart';
import 'package:primitives/primitives.dart';
import 'package:labels/labels.dart';
import 'package:secrets/testing.dart' show FakeSecureStoragePlatform;
import 'package:sync/sync.dart'
    show AddressBook, Keychain, DerivedAddress, WalletKey;
import 'package:sync/testing.dart' show testWallet;
import 'package:sync/write.dart' show WalletNativeLifecycle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/inventory_fixture.dart';

class _Native extends Mock implements WalletNativeLifecycle {}

class _Labels extends Mock implements Labels {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Liquid address history keeps the issued high-water when labels fail',
    () async {
      const id = 'elwpkh([aabbccdd/84h/1776h/0h])';
      FakeSecureStoragePlatform().install();
      final dir = await Directory.systemTemp.createTemp('address-history');
      addTearDown(() => dir.delete(recursive: true));
      final fixture = await InventoryFixture.open(dir);
      addTearDown(fixture.close);
      await fixture.addPublicWallet(id: id, network: 'liquidMainnet');
      final key = WalletKey(id: id, network: LiquidNetwork.mainnet);
      final native = _Native();
      final labels = _Labels();
      when(() => native.issuedReceiveIndex(key))
          .thenAnswer((_) async => const Ok(7));
      final wallet = await testWallet(
        key: key,
        addresses: AddressBook(
          receiveIndex: 0,
          changeIndex: null,
          receive: [
            for (var index = 0; index <= 7; index++)
              DerivedAddress(
                keychain: Keychain.external,
                index: index,
                address: 'confidential$index',
              ),
          ],
          change: [],
        ),
      );
      when(() => labels.fetch(reference: any(named: 'reference')))
          .thenAnswer((_) async => const Err(LabelUnexpectedFailure()));
      final repository = AddressView.open(
        native: native,
        labels: labels,
        inventory: fixture.inventory,
        loadWallet: (requested) async {
          expect(requested, key);
          return Ok(wallet);
        },
      );
      final addresses = await repository.list(walletId: id, limit: 3);
      expect(
        addresses,
        isA<Ok<List<WalletAddress>, AddressViewFailure>>()
            .having(
              (result) => result.value.map((address) => address.index),
              'indexes',
              [7, 6, 5],
            )
            .having(
              (result) => result.value.expand((address) => address.labels),
              'labels',
              isEmpty,
            ),
      );
      final next = await repository.list(walletId: id, limit: 2, fromIndex: 4);
      expect(
        next,
        isA<Ok<List<WalletAddress>, AddressViewFailure>>().having(
          (result) => result.value.map((address) => address.index),
          'indexes',
          [4, 3],
        ),
      );
    },
  );
}
