import 'dart:io';
import 'dart:typed_data';

import 'package:labels/labels.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/sync_freezes_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/coins/data/wallet_utxo_repository_impl.dart';
import 'package:legacy_storage/app_database.dart' show Signer;
import 'package:bb_mobile/features/wallet/domain/wallet.dart'
    as app
    show Network;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show WalletSnapshotException;
import 'package:sync/sync.dart' as sync;
import 'package:sync/testing.dart';

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Labels extends Mock implements Labels {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const walletId = 'wpkh([73c5da0a/84h/1h/0h])';
  final key = sync.WalletKey(id: walletId, network: BitcoinNetwork.testnet);
  final kept = (txId: 'a' * 64, vout: 0);
  final frozen = (txId: 'b' * 64, vout: 1);

  late Directory dir;
  late sync.Sync owner;
  late _Metadata metadata;
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
    metadata = _Metadata();
    labels = _Labels();
    when(() => metadata.fetch(walletId))
        .thenAnswer((_) async => _row(walletId));
    when(() => labels.fetch(reference: any(named: 'reference')))
        .thenAnswer((_) async => Ok([]));
  });
  tearDown(() async {
    await owner.close();
    dir.deleteSync(recursive: true);
  });

  WalletUtxoRepositoryImpl repository(sync.Wallet wallet) =>
      WalletUtxoRepositoryImpl(
        walletMetadataDatasource: metadata,
        labelsFacade: labels,
        loadWallet: (_) async => Ok(wallet),
        freezesDatasource: SyncFreezesDatasource(sync: () async => owner),
      );

  test('coins carry the frozen state sync publishes', () async {
    final wallet = await testWallet(
      key: key,
      coins: [coin(kept), coin(frozen)],
      frozen: {frozen},
    );

    final utxos = await repository(wallet).getWalletUtxos(walletId: walletId);

    expect(
      {for (final u in utxos) u.outpoint: u.isFrozen},
      {kept: false, frozen: true},
    );
  });

  test('unfreeze lifts a freeze attributed to another origin', () async {
    final freezes = SyncFreezesDatasource(sync: () async => owner);
    await freezes.freezeAttributed([
      sync.FrozenOutpoint(frozen, origin: ''),
      sync.FrozenOutpoint(frozen, origin: 'tr([73c5da0a/86h/1h/0h])'),
    ]);
    final wallet = await testWallet(key: key);

    await repository(wallet)
        .unfreezeUtxos(walletId: walletId, outpoints: [frozen]);

    expect(await repository(wallet).getAllFrozenOutpoints(), isEmpty);
  });

  test('an unreadable freeze store fails; it is never empty', () async {
    final broken = freezesOnlySync(
      '${dir.path}/broken',
      freezes: MemoryFreezeStore()..failure = const sync.SyncStorageFailure(),
    );
    addTearDown(broken.close);
    final freezes = SyncFreezesDatasource(sync: () async => broken);

    await expectLater(
      freezes.getFrozenOutpoints(),
      throwsA(
        isA<WalletSnapshotException>().having(
          (e) => e.failure,
          'failure',
          isA<sync.SyncStorageFailure>(),
        ),
      ),
    );
  });
}

WalletMetadataModel _row(String id) => WalletMetadataModel(
  id: id,
  networkCode: app.Network.bitcoinTestnet.name,
  masterFingerprint: '73c5da0a',
  xpubFingerprint: 'deadbeef',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'public-test-key',
  externalPublicDescriptor: 'wpkh(public-test-key/0/*)',
  internalPublicDescriptor: 'wpkh(public-test-key/1/*)',
  signer: Signer.local,
  isDefault: true,
);
