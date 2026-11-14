import 'package:primitives/primitives.dart';
import 'package:test/test.dart';
import 'package:transaction_sync/src/write/native_store_paths.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  test('identity includes chain and environment, preserves the exact id', () {
    final key = WalletKey(id: 'A', network: BitcoinNetwork.mainnet);
    expect(key, WalletKey(id: 'A', network: BitcoinNetwork.mainnet));
    expect(
      key.hashCode,
      WalletKey(id: 'A', network: BitcoinNetwork.mainnet).hashCode,
    );
    expect(key, isNot(WalletKey(id: 'a', network: BitcoinNetwork.mainnet)));
    expect(key, isNot(WalletKey(id: 'A', network: BitcoinNetwork.testnet)));
    expect(key, isNot(WalletKey(id: 'A', network: LiquidNetwork.mainnet)));
    expect(
      () => WalletKey(id: '', network: BitcoinNetwork.mainnet),
      throwsArgumentError,
    );
  });

  test(
    'legacy storage golden: origin, UTF-16 and root remain byte-identical',
    () {
      // Literal output of the legacy WalletModel.hexId and Bdk/LwkFacade paths.
      const cases = {
        'wpkh([aabbccdd/84h/0h/0h])':
            '77706b68285b61616262636364642f3834682f30682f30685d29',
        'elwpkh([aabbccdd/84h/1776h/0h])':
            '656c77706b68285b61616262636364642f3834682f31373736682f30685d29',
        'é😀': 'e9d83dde00',
      };
      for (final entry in cases.entries) {
        for (final network in <Network>[
          BitcoinNetwork.mainnet,
          BitcoinNetwork.testnet,
          LiquidNetwork.mainnet,
          LiquidNetwork.testnet,
        ]) {
          final suffix = network is BitcoinNetwork ? '_bdk_dart' : '';
          expect(
            nativeWalletStoragePath(
              '/data/wallets/',
              WalletKey(id: entry.key, network: network),
            ),
            '/data/wallets//${entry.value}$suffix',
          );
        }
      }
    },
  );

  test(
    'legacy storage refuses networks whose origins collide with testnet',
    () {
      for (final network in <Network>[
        BitcoinNetwork.signet,
        BitcoinNetwork.regtest,
        LiquidNetwork.regtest,
      ]) {
        expect(
          () => nativeWalletStoragePath(
            '/data/wallets',
            WalletKey(id: 'origin', network: network),
          ),
          throwsArgumentError,
        );
      }
    },
  );

  test('regtest storage hex includes the reserved suffix', () {
    expect(
      nativeWalletStoragePath(
        '/data',
        WalletKey(id: 'origin:regtest', network: BitcoinNetwork.regtest),
      ),
      '/data/6f726967696e3a72656774657374_bdk_dart',
    );
    expect(
      () => nativeWalletStoragePath(
        '/data',
        WalletKey(id: ':regtest', network: BitcoinNetwork.regtest),
      ),
      throwsArgumentError,
    );
  });

  test('revision equality includes lifecycle generation and key', () {
    final key = WalletKey(id: 'wallet', network: BitcoinNetwork.mainnet);
    final revision = WalletRevision(key: key, generation: 2, revision: 3);
    expect(revision, WalletRevision(key: key, generation: 2, revision: 3));
    expect(
      revision,
      isNot(WalletRevision(key: key, generation: 3, revision: 3)),
    );
    expect(
      () => WalletRevision(key: key, generation: -1, revision: 0),
      throwsArgumentError,
    );
    expect(
      () => WalletRevision(key: key, generation: 0, revision: -1),
      throwsArgumentError,
    );
    expect(
      () => ReceiveAddressIssued(revision, address: '', index: 0),
      throwsArgumentError,
    );
    expect(
      const TransactionSyncBusyFailure().toString(),
      'TransactionSyncBusyFailure',
    );
  });
}
