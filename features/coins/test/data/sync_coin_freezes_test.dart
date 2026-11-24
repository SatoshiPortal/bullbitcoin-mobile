import 'dart:io';
import 'dart:typed_data';

import 'package:labels/labels.dart';
import 'package:coins/coins.dart';
import 'package:coins/src/data/wallet_utxo_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show WalletInventory;
import 'package:secrets/testing.dart';
import 'package:sync/sync.dart' as sync;
import 'package:sync/testing.dart';

class _Labels extends Mock implements Labels {}

class _Inventory extends Mock implements WalletInventory {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const walletId = 'wpkh([73c5da0a/84h/1h/0h])';
  final key = sync.WalletKey(id: walletId, network: BitcoinNetwork.testnet);
  final kept = (txId: 'a' * 64, vout: 0);
  final frozen = (txId: 'b' * 64, vout: 1);

  late Directory dir;
  late sync.Sync owner;
  late _Labels labels;

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
    labels = _Labels();
    when(() => labels.fetch(reference: any(named: 'reference')))
        .thenAnswer((_) async => Ok([]));
  });
  tearDown(() async {
    await owner.close();
    dir.deleteSync(recursive: true);
  });

  WalletUtxoRepositoryImpl repository(sync.Wallet wallet) {
    final inventory = _Inventory();
    when(() => inventory.readWallet(walletId)).thenAnswer(
      (_) async => Ok(
        walletRegistrationForTesting(
          id: walletId,
          network: BitcoinNetwork.testnet,
        ),
      ),
    );
    return WalletUtxoRepositoryImpl(
      inventory: inventory,
      labelsFacade: labels,
      loadWallet: (_) async => Ok(wallet),
      foreground: () async => Ok(owner),
    );
  }

  test('coins carry the frozen state sync publishes', () async {
    final wallet = await testWallet(
      key: key,
      coins: [coin(kept), coin(frozen)],
      frozen: {frozen},
    );

    final result = await repository(wallet).getWalletUtxos(walletId: walletId);
    final utxos = (result as Ok<List<WalletUtxo>, CoinsFailure>).value;

    expect(
      {for (final u in utxos) u.outpoint: u.isFrozen},
      {kept: false, frozen: true},
    );
  });

  test('unfreeze lifts a freeze attributed to another origin', () async {
    expect(await owner.coins.freeze(frozen, origin: ''), isA<Ok>());
    expect(
      await owner.coins.freeze(frozen, origin: 'tr([73c5da0a/86h/1h/0h])'),
      isA<Ok>(),
    );
    final wallet = await testWallet(key: key);

    expect(
      await repository(wallet)
          .unfreezeUtxos(walletId: 'another wallet', outpoints: [frozen]),
      isA<Ok>(),
    );
    final result = await repository(wallet).getAllFrozenOutpoints();
    expect((result as Ok<List<Outpoint>, CoinsFailure>).value, isEmpty);
  });

  test('an unreadable freeze store fails; it is never empty', () async {
    final broken = freezesOnlySync(
      '${dir.path}/broken',
      freezes: MemoryFreezeStore()..failure = const sync.SyncStorageFailure(),
    );
    addTearDown(broken.close);
    final repository = WalletUtxoRepositoryImpl(
      inventory: _Inventory(),
      labelsFacade: labels,
      loadWallet: (_) async => fail('unexpected wallet load'),
      foreground: () async => Ok(broken),
    );
    expect(
      await repository.getAllFrozenOutpoints(),
      isA<Err<List<Outpoint>, CoinsFailure>>().having(
        (e) => e.failure,
        'failure',
        isA<CoinsLoadFailure>(),
      ),
    );
  });
}
