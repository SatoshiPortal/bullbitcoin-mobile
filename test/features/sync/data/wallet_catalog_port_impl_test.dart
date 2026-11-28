import 'package:secrets/secrets.dart' show SecretFailure, StoreSecretFailure;
import 'package:secrets/storage.dart' show RegisteredWalletDescriptor;
import 'package:sync/testing.dart' show catalogForTesting;

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

final class _Catalog {
  List<RegisteredWalletDescriptor> rows = [];
  bool fail = false;
  bool throwState = false;

  Future<Result<List<RegisteredWalletDescriptor>, SecretFailure>> read() async {
    if (throwState) throw StateError('programmer failure');
    if (fail) return const Err(StoreSecretFailure('private diagnostic'));
    return Ok(rows);
  }
}

RegisteredWalletDescriptor _descriptorRow(
  String origin, {
  String networkCode = 'bitcoinMainnet',
  String external = 'wpkh(public)',
  String internal = 'wpkh(change)',
}) => RegisteredWalletDescriptor(
  id: origin,
  network: networkCode,
  externalDescriptor: external,
  internalDescriptor: internal,
);

void main() {
  test(
    'catalog preserves identity, descriptor strings and all legacy networks',
    () async {
      final catalog = _Catalog();
      final port = catalogForTesting(catalog.read);
      const networks = <String, Network>{
        'wpkh([aabbccdd/84h/0h/0h])': BitcoinNetwork.mainnet,
        'sh(wpkh([aabbccdd/49h/1h/0h]))': BitcoinNetwork.testnet,
        'elwpkh([aabbccdd/84h/1776h/0h])': LiquidNetwork.mainnet,
        'elpkh([aabbccdd/44h/1h/0h])': LiquidNetwork.testnet,
        'wpkh([aabbccdd/84h/1h/0h]):regtest': BitcoinNetwork.regtest,
        'elwpkh([aabbccdd/84h/1h/0h]):regtest': LiquidNetwork.regtest,
      };
      const confidential = 'ct(slip77(PRIVACY_PLACEHOLDER),elwpkh(public))';
      catalog.rows = networks.entries
          .map(
            (entry) => entry.value is LiquidNetwork
                ? _descriptorRow(
                    entry.key,
                    networkCode: switch (entry.value) {
                      LiquidNetwork.mainnet => 'liquidMainnet',
                      LiquidNetwork.regtest => 'liquidRegtest',
                      _ => 'liquidTestnet',
                    },
                    external: confidential,
                    internal: 'unused Liquid internal descriptor',
                  )
                : _descriptorRow(
                    entry.key,
                    networkCode: switch (entry.value) {
                      BitcoinNetwork.mainnet => 'bitcoinMainnet',
                      BitcoinNetwork.regtest => 'bitcoinRegtest',
                      _ => 'bitcoinTestnet',
                    },
                  ),
          )
          .toList();
      final result =
          await port.list() as Ok<List<PublicWalletDescriptor>, SyncFailure>;
      expect(result.value, hasLength(6));
      expect(() => result.value.clear(), throwsUnsupportedError);
      for (final entry in networks.entries) {
        final key = WalletKey(id: entry.key, network: entry.value);
        final found =
            await port.find(key) as Ok<PublicWalletDescriptor, SyncFailure>;
        expect(found.value.key, key);
        expect(found.value.origin, entry.key.replaceAll(':regtest', ''));
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
        ScriptType.bip84,
        ScriptType.bip84,
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

  test('invalid descriptor is refused before issuing a native key', () async {
    const origin = 'wpkh([aabbccdd/84h/0h/0h])';
    final catalog = _Catalog()..rows = [_descriptorRow(origin, external: '')];
    final result = await catalogForTesting(catalog.read)
        .find(WalletKey(id: origin, network: BitcoinNetwork.mainnet));
    expect(
      result,
      isA<Err<PublicWalletDescriptor, SyncFailure>>().having(
        (error) => error.failure,
        'failure',
        isA<SyncInvalidCatalogFailure>(),
      ),
    );
  });

  test('invalid rows do not hide valid catalog entries', () async {
    final catalog = _Catalog();
    final port = catalogForTesting(catalog.read);
    const bitcoin = 'wpkh([aabbccdd/84h/0h/0h])';
    const liquid = 'elwpkh([aabbccdd/84h/1776h/0h])';
    for (final invalid in [
      _descriptorRow('invalid'),
      _descriptorRow(bitcoin, external: 'wpkh(xprvINVALID)'),
      _descriptorRow(
        liquid,
        networkCode: 'liquidMainnet',
        external: 'elwpkh(public)',
      ),
    ]) {
      catalog.rows = [_descriptorRow(bitcoin), invalid];
      final result =
          await port.list() as Ok<List<PublicWalletDescriptor>, SyncFailure>;
      expect(result.value, hasLength(1));
    }
    catalog.fail = true;
    final result = await port.find(
      WalletKey(id: bitcoin, network: BitcoinNetwork.mainnet),
    ) as Err<PublicWalletDescriptor, SyncFailure>;
    expect(result.failure, isA<SyncStorageFailure>());
    expect(result.failure.toString(), isNot(contains('private diagnostic')));
    catalog.fail = false;
    catalog.throwState = true;
    await expectLater(port.list(), throwsStateError);
  });
}
