import 'dart:io';

import 'package:bb_mobile/features/wallet/data/wallet_catalog_port_impl.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' as p;
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/write.dart';

// Published BIP84 test account, shared with wallet_identity_pins_test.dart.
const _vpub =
    'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc';

class _Catalog implements WalletCatalogPort {
  PublicWalletDescriptor descriptor;
  _Catalog(this.descriptor);
  @override
  Future<p.Result<PublicWalletDescriptor, TransactionSyncFailure>> find(
    WalletKey key,
  ) async => p.Ok(descriptor);
  @override
  Future<p.Result<List<PublicWalletDescriptor>, TransactionSyncFailure>>
  list() async => p.Ok([descriptor]);
}

class _Reserved implements ReservedAddressPort {
  @override
  Future<p.Result<bool, TransactionSyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const p.Ok(false);
}

void main() {
  test('mainnet descriptor retains BIP32 mainnet key version', () async {
    final metadata = await WalletMetadataService.deriveFromXpub(
      xpub:
          'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj',
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
    );
    expect(metadata.externalPublicDescriptor, contains('xpub'));
    expect(metadata.internalPublicDescriptor, contains('xpub'));
  });
  for (final interrupted in [false, true]) {
    test(
      'published test vpub creates through the native writer interrupted=$interrupted',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'watch-only-native-',
        );
        final revisions = RevisionStore('${directory.path}/revisions.sqlite');
        try {
          final metadata = await WalletMetadataService.deriveFromXpub(
            xpub: _vpub,
            network: Network.bitcoinTestnet,
            scriptType: ScriptType.bip84,
          );
          final descriptor =
              (WalletCatalogPortImpl.descriptorFromMetadata(metadata)
                      as p.Ok<PublicWalletDescriptor, TransactionSyncFailure>)
                  .value;
          final catalog = _Catalog(descriptor);
          final writer = NativeWalletWriter(
            lockDirectory: '${directory.path}/locks',
            revisions: revisions,
            documentsDirectory: directory.path,
            catalog: catalog,
            reservedAddresses: _Reserved(),
          );
          if (interrupted) {
            catalog.descriptor = BitcoinWalletDescriptor(
              key: descriptor.key,
              scriptType: p.ScriptType.bip84,
              origin: descriptor.origin,
              externalDescriptor: 'wpkh(invalid)',
              internalDescriptor: 'wpkh(invalid)',
            );
            expect(
              await writer.create(descriptor.key, expectedGeneration: 0),
              isA<p.Err>(),
            );
            catalog.descriptor = descriptor;
          }
          expect(
            await writer.create(
              descriptor.key,
              expectedGeneration: interrupted ? 1 : 0,
            ),
            isA<p.Ok>(),
          );
          expect(
            await revisions.read(descriptor.key),
            isA<p.Ok<WalletRevisionState, TransactionSyncFailure>>().having(
              (result) => result.value.lifecycle,
              'lifecycle',
              WalletLifecycle.active,
            ),
          );
          expect(
            await writer.receive(descriptor.key, expectedGeneration: 1),
            isA<p.Ok>(),
          );
        } finally {
          await revisions.close();
          directory.deleteSync(recursive: true);
        }
      },
    );
  }
}
