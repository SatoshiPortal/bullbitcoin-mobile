import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:labels/backup.dart';
import 'package:labels/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart' show multiViewSupported;
import 'package:secrets/testing.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart';

import '../../../support/inventory_fixture.dart';

const _id = 'wpkh([01234567/84h/1h/0h])';

class _Inventory extends Mock implements WalletInventory {}

class _Reserved extends Mock implements ReservedAddressPort {}

class _Reservations extends Mock implements InputReservationPort {}

class _Connections extends Mock implements WalletConnectionPort {}

final class _Catalog implements WalletCatalogPort {
  final keys = <WalletKey>[];
  SyncFailure failure = const SyncInvalidCatalogFailure();

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async {
    keys.add(key);
    return Err(failure);
  }

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      const Ok([]);
}

Matcher _failure<T extends SyncFailure>() => isA<WalletSnapshotException>()
    .having((e) => e.failure, 'failure', isA<T>());

T _value<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('Unexpected ${failure.runtimeType}'),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Labels wallet resolution', () {
    late _Inventory inventory;
    late _Catalog catalog;
    late GetIt locator;
    late Future<Wallet> Function(String) openWallet;
    late int runtimeResolutions;

    setUp(() {
      inventory = _Inventory();
      catalog = _Catalog();
      locator = GetIt.asNewInstance();
      openWallet = AuthorizedWalletAccess(
        inventory: inventory,
        runtime: locator.call<WalletNativeRuntime>,
      ).open;
      final dir = Directory.systemTemp.createTempSync('labels-sync-');
      addTearDown(() => dir.delete(recursive: true));
      addTearDown(locator.reset);
      locator.registerSingleton<WalletInventory>(inventory);
      final connections = _Connections();
      Future<String> directory() async => dir.path;
      runtimeResolutions = 0;
      locator.registerLazySingleton<WalletNativeRuntime>(() {
        runtimeResolutions++;
        return WalletNativeRuntime.open(
          catalog: catalog,
          reserved: _Reserved(),
          inputReservations: _Reservations(),
          deleteCatalogEntry: (_) async => const Ok(null),
          sync: ElectrumSync(
            connections: connections,
            documentsDirectory: directory,
            readRevision: (_) async => const Err(SyncNotFoundFailure()),
          ),
          documentsDirectory: directory,
          freezes: MemoryFreezeStore(),
          connections: connections,
        );
      }, dispose: (runtime) => runtime.close());
    });

    void row(BitcoinNetwork network) => when(() => inventory.readWallet(_id))
        .thenAnswer(
          (_) async =>
              Ok(walletRegistrationForTesting(id: _id, network: network)),
        );

    test(
      'an invisible ID never reaches the runtime despite a cached row',
      () async {
        when(() => inventory.readWallet(_id)).thenAnswer(
          (_) async => const Err(WalletRegistrationNotFoundFailure()),
        );
        await expectLater(
          openWallet(_id),
          throwsA(_failure<SyncNotFoundFailure>()),
        );
        expect(runtimeResolutions, 0);
        expect(catalog.keys, isEmpty);
      },
    );

    for (final failure in [
      const FetchSecretFailure(),
      const UnreadableWalletFailure(),
      const SecretNotFoundFailure(),
    ]) {
      test(
        '${failure.runtimeType} is a storage failure, not absence',
        () async {
          when(() => inventory.readWallet(_id))
              .thenAnswer((_) async => Err(failure));
          await expectLater(
            openWallet(_id),
            throwsA(_failure<SyncStorageFailure>()),
          );
          expect(runtimeResolutions, 0);
          expect(catalog.keys, isEmpty);
        },
      );
    }

    test(
      'forwards the exact inventory network and preserves a catalog failure',
      () async {
        row(BitcoinNetwork.testnet);
        await expectLater(
          openWallet(_id),
          throwsA(_failure<SyncInvalidCatalogFailure>()),
        );
        expect(catalog.keys, [
          WalletKey(id: _id, network: BitcoinNetwork.testnet),
        ]);
      },
    );

    test(
      'a missing native catalog entry is not a missing inventory row',
      () async {
        row(BitcoinNetwork.testnet);
        catalog.failure = const SyncNotFoundFailure();
        await expectLater(
          openWallet(_id),
          throwsA(_failure<SyncInvalidCatalogFailure>()),
        );
        expect(catalog.keys, [
          WalletKey(id: _id, network: BitcoinNetwork.testnet),
        ]);
      },
    );

    test(
      'refuses a Signet wallet without falling back or opening native storage',
      () async {
        row(BitcoinNetwork.signet);
        await expectLater(
          openWallet(_id),
          throwsA(_failure<SyncUnsupportedNetworkFailure>()),
        );
        expect(runtimeResolutions, 0);
        expect(catalog.keys, isEmpty);
      },
    );
  });

  test(
    'restoration cannot use outpoints from a load spanning A to B to A',
    () async {
      FakeSecureStoragePlatform().install();
      final directory = await Directory.systemTemp.createTemp('labels-view-');
      addTearDown(() => directory.delete(recursive: true));
      final fixture = await InventoryFixture.open(directory);
      addTearDown(fixture.close);
      final inventory = fixture.inventory;
      await fixture.addPublicWallet(id: _id, network: 'bitcoinTestnet');
      final views = inventory.openedViews ?? fail('Expected an open inventory');
      final first = inventory.activeView ?? fail('Expected an active view');
      final other = _value(await views.administration.create(name: 'Other')).id;
      final started = Completer<void>();
      final resume = Completer<void>();
      final outpoint = (txId: 'a' * 64, vout: 0);
      final key = WalletKey(id: _id, network: BitcoinNetwork.testnet);
      final wallet = await testWallet(
        key: key,
        coins: [
          BitcoinCoin(
            outpoint: outpoint,
            amountSat: BigInt.from(1000),
            scriptPubkey: Uint8List.fromList([0]),
            address: 'tb1q',
            keychain: Keychain.external,
            confirmations: 1,
          ),
        ],
        load: false,
        beforeFirstFrame: () {
          started.complete();
          return resume.future;
        },
      );
      final database = LabelsDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final owner = freezesOnlySync(directory.path);
      addTearDown(owner.close);
      final labels = createLabelsForTesting(
        database: database,
        listAttributedFreezes: owner.coins.listFrozen,
        freezeAttributedOutpoints: (_) => fail('Unexpected freeze'),
        readInSession: (read) => inventory.readInSession(read),
        openWallet: (id) async {
          expect(id, _id);
          expect(await inventory.readWallet(id), isA<Ok>());
          return wallet;
        },
      );
      final scope = LabelBackupScope(
        groupId: 'test',
        bitcoinWalletIds: [_id],
        liquidWalletIds: [],
        allWalletIds: [_id],
      );
      final ref = '${outpoint.txId}:${outpoint.vout}';
      final plan = _value(
        await labels.backup.preview(
          scope,
          LabelsSnapshot(
            records: [
              BackupLabelRecord(
                chain: BackupLabelChain.bitcoin,
                type: BackupLabelType.output,
                ref: ref,
                spendable: false,
                walletId: _id,
              ),
            ],
            unattributedCount: 0,
            skippedCount: 0,
          ),
        ),
      );
      final applying = labels.backup.apply(scope, plan, MergeChoices({}));
      await Future.any([
        started.future,
        applying.then<void>(
          (result) => fail('Restore finished early: $result'),
        ),
      ]);
      try {
        expect(await views.activate(other), isA<Ok>());
        expect(await inventory.readWallet(_id), isA<Err>());
        expect(await views.activate(first), isA<Ok>());
        expect(await inventory.readWallet(_id), isA<Ok>());
      } finally {
        resume.complete();
      }
      expect(_value(await applying).freezes.values, [FreezeOutcome.failed]);
      expect(_value(await owner.coins.listFrozen()), isEmpty);
      expect(
        _value(await labels.backup.apply(scope, plan, MergeChoices({})))
            .freezes
            .values,
        [FreezeOutcome.applied],
      );
    },
    skip: multiViewSupported ? false : 'Requires BULL_MULTI_VIEW=true',
  );
}
