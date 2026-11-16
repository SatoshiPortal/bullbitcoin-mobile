import 'package:bb_mobile/features/wallet/domain/wallet.dart' as app;

import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';

import '../../../core_test/wallet/wallet_signer_test_fixture.dart';

import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_catalog_port_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

final class _Catalog implements WalletMetadataDatasource {
  List<WalletMetadataModel> rows = [];
  Object? failure;

  @override
  Future<List<WalletMetadataModel>> fetchAll() async {
    final error = failure;
    if (error != null) throw error;
    return rows;
  }

  @override
  Future<WalletMetadataModel?> fetch(String walletId) async =>
      (await fetchAll()).where((row) => row.id == walletId).firstOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WalletMetadataModel _row(
  String origin, {
  String networkCode = 'bitcoinMainnet',
  String? external,
  String internal = 'wpkh(change)',
}) => WalletMetadataModel(
  id: origin,
  networkCode: networkCode,
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  isDefault: false,
  signers: [
    walletSignerModel(
      id: 'signer-0',
      descriptorKeyId: 'key-0',
      masterFingerprint: 'aabbccdd',
      xpubFingerprint: 'aabbccdd',
      xpub: 'public',
      signer: Signer.none,
      signerDevice: null,
    ),
  ],
  publicDescriptor:
      external ??
      watchOnlyMetadata(
        xpub: networkCode == 'bitcoinMainnet'
            ? 'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj'
            : 'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc',
        network: networkCode == 'bitcoinMainnet'
            ? app.Network.bitcoinMainnet
            : app.Network.bitcoinTestnet,
        scriptType: origin.startsWith('sh(')
            ? app.ScriptType.bip49
            : app.ScriptType.bip84,
      ).publicDescriptor,
);

void main() {
  test(
    'catalog preserves identity, descriptor strings and all legacy networks',
    () async {
      final catalog = _Catalog();
      final port = WalletCatalogPortImpl(catalog);
      const networks = <String, Network>{
        'wpkh([aabbccdd/84h/0h/0h])': BitcoinNetwork.mainnet,
        'sh(wpkh([aabbccdd/49h/1h/0h]))': BitcoinNetwork.testnet,
        'elwpkh([aabbccdd/84h/1776h/0h])': LiquidNetwork.mainnet,
        'elpkh([aabbccdd/44h/1h/0h])': LiquidNetwork.testnet,
      };
      const confidential = 'ct(slip77(PRIVACY_PLACEHOLDER),elwpkh(public))';
      catalog.rows = networks.entries
          .map(
            (entry) => entry.value is LiquidNetwork
                ? _row(
                    entry.key,
                    networkCode: entry.value == LiquidNetwork.mainnet
                        ? 'liquidMainnet'
                        : 'liquidTestnet',
                    external: confidential,
                    internal: 'unused Liquid internal descriptor',
                  )
                : _row(
                    entry.key,
                    networkCode: entry.value == BitcoinNetwork.mainnet
                        ? 'bitcoinMainnet'
                        : 'bitcoinTestnet',
                  ),
          )
          .toList();
      final result =
          await port.list() as Ok<List<PublicWalletDescriptor>, SyncFailure>;
      expect(result.value, hasLength(4));
      expect(() => result.value.clear(), throwsUnsupportedError);
      for (final entry in networks.entries) {
        final key = WalletKey(id: entry.key, network: entry.value);
        final found =
            await port.find(key) as Ok<PublicWalletDescriptor, SyncFailure>;
        expect(found.value.key, key);
        expect(found.value.origin, entry.key);
        switch (found.value) {
          case BitcoinWalletDescriptor(
            :final externalDescriptor,
            :final internalDescriptor,
          ):
            expect(externalDescriptor, contains('/0/*'));
            expect(internalDescriptor, contains('/1/*'));
          case LiquidWalletDescriptor(:final combinedCtDescriptor):
            expect(combinedCtDescriptor, confidential);
            expect(
              found.value.toString(),
              isNot(contains('PRIVACY_PLACEHOLDER')),
            );
        }
      }
      expect(result.value.map((value) => value.scriptType), [
        ScriptType.bip84,
        ScriptType.bip49,
        ScriptType.bip84,
        ScriptType.bip44,
      ]);
      for (final key in [
        WalletKey(id: 'missing', network: BitcoinNetwork.mainnet),
        WalletKey(id: networks.keys.first, network: BitcoinNetwork.signet),
      ]) {
        final missing =
            await port.find(key) as Err<PublicWalletDescriptor, SyncFailure>;
        expect(missing.failure, isA<SyncNotFoundFailure>());
      }
    },
  );

  test('invalid rows do not hide valid catalog entries', () async {
    final catalog = _Catalog();
    final port = WalletCatalogPortImpl(catalog);
    const bitcoin = 'wpkh([aabbccdd/84h/0h/0h])';
    const liquid = 'elwpkh([aabbccdd/84h/1776h/0h])';
    for (final invalid in [
      _row('invalid', networkCode: 'unresolved'),
      _row(bitcoin, external: 'wpkh(xprvINVALID)'),
      _row(liquid, external: 'elwpkh(public)'),
    ]) {
      catalog.rows = [_row(bitcoin), invalid];
      final result =
          await port.list() as Ok<List<PublicWalletDescriptor>, SyncFailure>;
      expect(result.value, hasLength(1));
    }
    catalog.failure = Exception('private diagnostic');
    final result = await port.find(
      WalletKey(id: bitcoin, network: BitcoinNetwork.mainnet),
    ) as Err<PublicWalletDescriptor, SyncFailure>;
    expect(result.failure, isA<SyncStorageFailure>());
    expect(result.failure.toString(), isNot(contains('private diagnostic')));
    catalog.failure = StateError('programmer failure');
    await expectLater(port.list(), throwsStateError);
  });
}
