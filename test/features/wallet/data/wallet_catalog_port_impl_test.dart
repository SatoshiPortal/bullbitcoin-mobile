import '../../../support/wallet_registrations.dart';

import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:legacy_storage/app_database.dart' show Signer;
import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

final class _Catalog implements WalletRegistrations {
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
  String external = 'wpkh(public)',
  String internal = 'wpkh(change)',
}) => WalletMetadataModel(
  id: origin,
  networkCode: networkCode,
  masterFingerprint: 'aabbccdd',
  xpubFingerprint: 'aabbccdd',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'public',
  externalPublicDescriptor: external,
  internalPublicDescriptor: internal,
  signer: Signer.none,
  isDefault: false,
);

void main() {
  test(
    'catalog preserves identity, descriptor strings and all legacy networks',
    () async {
      final catalog = _Catalog();
      final port = TestWalletCatalog(catalog);
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
            expect(externalDescriptor, 'wpkh(public)');
            expect(internalDescriptor, 'wpkh(change)');
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

  test('invalid descriptor is refused before issuing a native key', () {
    final invalid = _row('wpkh([aabbccdd/84h/0h/0h])', external: '');
    expect(
      () => WalletSyncBinding.keyFromMetadata(invalid),
      throwsA(
        isA<WalletSnapshotException>().having(
          (error) => error.failure,
          'failure',
          isA<SyncInvalidCatalogFailure>(),
        ),
      ),
    );
  });

  test('invalid rows do not hide valid catalog entries', () async {
    final catalog = _Catalog();
    final port = TestWalletCatalog(catalog);
    const bitcoin = 'wpkh([aabbccdd/84h/0h/0h])';
    const liquid = 'elwpkh([aabbccdd/84h/1776h/0h])';
    for (final invalid in [
      _row('invalid'),
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
