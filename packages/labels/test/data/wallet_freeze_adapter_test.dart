import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:labels/src/data/wallet_freeze_adapter.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show WalletSnapshotException;
import 'package:sync/sync.dart' as sync;
import 'package:sync/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const walletId = 'wpkh([73c5da0a/84h/1h/0h])';
  final key = sync.WalletKey(id: walletId, network: BitcoinNetwork.testnet);
  final kept = (txId: 'a' * 64, vout: 0);
  final frozen = (txId: 'b' * 64, vout: 1);

  late Directory dir;
  late sync.Sync owner;

  sync.BitcoinCoin coin(Outpoint outpoint) => sync.BitcoinCoin(
    outpoint: outpoint,
    amountSat: BigInt.from(1000),
    scriptPubkey: Uint8List.fromList([0]),
    address: 'tb1q',
    keychain: sync.Keychain.external,
    confirmations: 1,
  );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('coin-freezes-');
    owner = freezesOnlySync(dir.path);
  });
  tearDown(() async {
    await owner.close();
    dir.deleteSync(recursive: true);
  });

  group('BIP329 adapter', () {
    for (final stale in [false, true]) {
      final status = stale ? sync.ValueStatus.stale : sync.ValueStatus.ready;
      test('reads owned outpoints from a ${status.name} snapshot', () async {
        final wallet = await testWallet(
          key: key,
          coins: [coin(kept), coin(frozen)],
          frozen: {frozen},
          stale: stale,
          load: false,
        );
        final adapter = WalletFreezeAdapter(
          readInSession: (read) async => Ok(await read()),
          listAttributedFreezes: () => fail('Unexpected freeze read'),
          freezeAttributedOutpoints: (_) => fail('Unexpected freeze'),
          openWallet: (id) async {
            expect(id, walletId);
            return wallet;
          },
        );

        expect(wallet.coins.now.status, sync.ValueStatus.notLoaded);
        expect(await adapter.getOwnedOutpoints(walletId: walletId), [
          kept,
          frozen,
        ]);
        expect(wallet.coins.now.status, status);
      });
    }

    test('does not report an absent wallet as an empty coin list', () async {
      const failure = WalletSnapshotException(sync.SyncNotFoundFailure());
      final adapter = WalletFreezeAdapter(
        readInSession: (read) async => Ok(await read()),
        listAttributedFreezes: () => fail('Unexpected freeze read'),
        freezeAttributedOutpoints: (_) => fail('Unexpected freeze'),
        openWallet: (_) async => throw failure,
      );

      await expectLater(
        adapter.getOwnedOutpoints(walletId: walletId),
        throwsA(same(failure)),
      );
    });

    test(
      'returns an empty list when the loaded wallet holds no coins',
      () async {
        final wallet = await testWallet(key: key, load: false);
        final adapter = WalletFreezeAdapter(
          listAttributedFreezes: () => fail('Unexpected freeze read'),
          freezeAttributedOutpoints: (_) => fail('Unexpected freeze'),
          openWallet: (_) async => wallet,
          readInSession: (read) async => Ok(await read()),
        );

        expect(await adapter.getOwnedOutpoints(walletId: walletId), isEmpty);
        expect(wallet.coins.now.status, sync.ValueStatus.ready);
      },
    );

    test('keeps every origin, empty ones included', () async {
      final adapter = WalletFreezeAdapter(
        readInSession: (_) =>
            throw StateError('Freeze needs no ownership read'),
        listAttributedFreezes: owner.coins.listFrozen,
        freezeAttributedOutpoints: (rows) async {
          for (final row in rows) {
            if (await owner.coins.freeze(row.outpoint, origin: row.origin)
                case Err(:final failure)) {
              return Err(failure);
            }
          }
          return const Ok(null);
        },
        openWallet: (_) => throw StateError('Freeze does not load a wallet'),
      );
      await adapter.freeze([
        (walletId: walletId, txId: kept.txId, vout: kept.vout),
        (walletId: null, txId: frozen.txId, vout: frozen.vout),
      ]);

      expect((await adapter.getAllFrozen()).toSet(), {
        (walletId: walletId, txId: kept.txId, vout: kept.vout),
        (walletId: '', txId: frozen.txId, vout: frozen.vout),
      });
    });
  });
}
