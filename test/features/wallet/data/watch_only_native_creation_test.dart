import 'package:primitives/primitives.dart' show ScriptType;

import 'dart:io';

import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sync/testing.dart' show NoConnections;

import 'package:primitives/primitives.dart' as p;
import 'package:sync/sync.dart';
import 'package:sync/write.dart';
import 'package:sync/testing.dart' show MemoryFreezeStore;

// Published BIP84 test account, shared with wallet_identity_pins_test.dart.
const _vpub =
    'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc';

class _Catalog implements WalletCatalogPort {
  PublicWalletDescriptor descriptor;
  _Catalog(this.descriptor);
  @override
  Future<p.Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async => p.Ok(descriptor);
  @override
  Future<p.Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      p.Ok([descriptor]);
}

class _Reserved implements ReservedAddressPort {
  @override
  Future<p.Result<bool, SyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const p.Ok(false);
}

void main() {
  test('mainnet descriptor retains BIP32 mainnet key version', () async {
    final metadata = await WalletMetadataService.deriveFromXpub(
      xpub: 'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj',
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
        ForegroundStores? stores;
        try {
          final metadata = await WalletMetadataService.deriveFromXpub(
            xpub: _vpub,
            network: Network.bitcoinTestnet,
            scriptType: ScriptType.bip84,
          );
          final descriptor = (WalletSyncBinding.descriptorFromMetadata(
            metadata,
          ) as p.Ok<PublicWalletDescriptor, SyncFailure>).value;
          final catalog = _Catalog(descriptor);
          final opened = stores = openForeground(
            documentsDirectory: directory.path,
            catalog: catalog,
            reservedAddresses: _Reserved(),
            freezes: MemoryFreezeStore(),
            inputReservations: _NoInputReservations(),
            connections: const NoConnections(),
          );
          final writer = opened.writer;
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
            await opened.revisions.read(descriptor.key),
            isA<p.Ok<WalletRevisionState, SyncFailure>>().having(
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
          await stores?.close();
          directory.deleteSync(recursive: true);
        }
      },
    );
  }
}

final class _NoInputReservations implements InputReservationPort {
  @override
  Future<p.Result<List<InputReservation>, SyncFailure>> reservations() async =>
      const p.Ok([]);
}
