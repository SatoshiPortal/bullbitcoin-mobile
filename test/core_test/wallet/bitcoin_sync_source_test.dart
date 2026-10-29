import 'dart:async';
import 'dart:typed_data';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';

import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/electrum_sync_source_guard.dart';
import 'package:bb_mobile/core/wallet/data/cbf_privacy_guard.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_bitcoin_sync_source_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _Bdk extends Mock implements BdkWalletDatasource {}

class _Lwk extends Mock implements LwkWalletDatasource {}

class _Servers extends Mock implements ElectrumServersPort {}

class _SyncMetadata extends Mock implements WalletSyncMetadataPort {}

const _id = 'wpkh([deadbeef/84h/0h/0h])';
const _other = 'wpkh([cafebabe/84h/0h/0h])';
const _liquid = 'elwpkh([deadbeef/84h/1776h/0h])';

WalletMetadataModel _metadata(String id) => WalletMetadataModel(
  id: id,
  masterFingerprint: 'deadbeef',
  xpubFingerprint: 'deadbeef',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'public',
  externalPublicDescriptor: 'wpkh(public/0/*)',
  internalPublicDescriptor: 'wpkh(public/1/*)',
  signer: Signer.none,
  isDefault: false,
  birthday: DateTime.utc(2020),
);

class _RecordingCoordinator implements WalletSourceOperationCoordinator {
  final delegate = InMemoryWalletSourceOperationCoordinator();
  final setterQueued = Completer<void>();

  @override
  Future<T> runExclusive<T>(
    WalletSourceKey key,
    Future<T> Function(WalletSourceSession) operation, {
    Duration? timeout = const Duration(seconds: 30),
    DateTime? admissionDeadline,
    bool allowRetired = false,
    WalletOperationKind kind = WalletOperationKind.refresh,
    WalletOperationPriority priority = WalletOperationPriority.foreground,
  }) {
    if (kind == WalletOperationKind.refresh && !setterQueued.isCompleted) {
      setterQueued.complete();
    }
    return delegate.runExclusive(
      key,
      operation,
      timeout: timeout,
      admissionDeadline: admissionDeadline,
      allowRetired: allowRetired,
      kind: kind,
      priority: priority,
    );
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const WalletModel.publicLwk(
        id: _liquid,
        combinedCtDescriptor: 'public',
        isTestnet: false,
      ),
    );
    registerFallbackValue(
      const WalletModel.publicBdk(
        id: _id,
        externalDescriptor: 'public',
        internalDescriptor: 'public',
        isTestnet: false,
      ),
    );
  });
  late SqliteDatabase db;
  late WalletMetadataDatasource metadata;
  late _Bdk bdk;
  late _Lwk lwk;
  late _Servers servers;
  late _RecordingCoordinator coordinator;
  late ElectrumSyncSourceGuard guard;
  late WalletRepository repository;
  late UpdateBitcoinSyncSourceUsecase update;

  setUp(() async {
    db = SqliteDatabase(NativeDatabase.memory());
    metadata = WalletMetadataDatasource(sqlite: db);
    bdk = _Bdk();
    lwk = _Lwk();
    servers = _Servers();
    coordinator = _RecordingCoordinator();
    guard = ElectrumSyncSourceGuard(
      coordinator: coordinator,
      metadata: metadata,
    );
    when(() => bdk.getBalance(wallet: any(named: 'wallet'))).thenAnswer(
      (_) async => BalanceModel(
        immatureSat: BigInt.zero,
        trustedPendingSat: BigInt.zero,
        untrustedPendingSat: BigInt.zero,
        confirmedSat: BigInt.zero,
        spendableSat: BigInt.zero,
        totalSat: BigInt.zero,
      ),
    );
    when(() => lwk.getBalance(wallet: any(named: 'wallet'))).thenAnswer(
      (_) async => BalanceModel(
        immatureSat: BigInt.zero,
        trustedPendingSat: BigInt.zero,
        untrustedPendingSat: BigInt.zero,
        confirmedSat: BigInt.zero,
        spendableSat: BigInt.zero,
        totalSat: BigInt.zero,
      ),
    );
    repository = WalletRepository(
      walletMetadataDatasource: metadata,
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: lwk,
      serversPort: servers,
      coordinator: guard,
      syncMetadata: _SyncMetadata(),
    );
    update = UpdateBitcoinSyncSourceUsecase(repository: repository);
    await metadata.store(_metadata(_id));
    await metadata.store(_metadata(_other));
    await metadata.store(_metadata(_liquid));
  });
  tearDown(() => db.close());

  test(
    'source round trips per wallet; changing it preserves identity and birthday',
    () async {
      final stale = await metadata.fetch(_id);
      expect(stale?.bitcoinSyncSource, BitcoinSyncSource.electrum);
      expect(
        await update.execute(
          walletId: _id,
          source: BitcoinSyncSource.compactBlockFilters,
        ),
        isA<Ok>(),
      );
      final changed = await metadata.fetch(_id);
      expect(changed?.bitcoinSyncSource, BitcoinSyncSource.compactBlockFilters);
      expect(changed?.id, stale?.id);
      expect(changed?.birthday, stale?.birthday);
      expect(
        (await metadata.fetch(_other))?.bitcoinSyncSource,
        BitcoinSyncSource.electrum,
      );
      final wallet = (await repository.getWallet(_id) as Ok).value as Wallet;
      expect(wallet.bitcoinSyncSource, BitcoinSyncSource.compactBlockFilters);
      // A backup read before the source change may finish writing afterwards.
      if (stale case final previous?) {
        await metadata.store(previous.copyWith(isPhysicalBackupTested: true));
      }
      expect(
        (await metadata.fetch(_id))?.bitcoinSyncSource,
        BitcoinSyncSource.compactBlockFilters,
      );
      expect((await metadata.fetch(_id))?.isPhysicalBackupTested, isTrue);
      expect(
        await update.execute(walletId: _id, source: BitcoinSyncSource.electrum),
        isA<Ok>(),
      );
      expect(
        (await metadata.fetch(_id))?.bitcoinSyncSource,
        BitcoinSyncSource.electrum,
      );
      verifyZeroInteractions(servers);
    },
  );

  test(
    'Liquid is persisted as Electrum and rejects a later CBF selection',
    () async {
      await metadata.delete(_liquid);
      await metadata.store(
        _metadata(
          _liquid,
        ).copyWith(bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters),
      );
      expect(
        (await metadata.fetch(_liquid))?.bitcoinSyncSource,
        BitcoinSyncSource.electrum,
      );
      final result = await update.execute(
        walletId: _liquid,
        source: BitcoinSyncSource.compactBlockFilters,
      );
      expect(
        (result as Err).failure,
        isA<WalletUnsupportedSyncSourceFailure>(),
      );
      expect(
        await update.execute(
          walletId: _liquid,
          source: BitcoinSyncSource.electrum,
        ),
        isA<Ok>(),
      );
      expect(
        (await update.execute(
                  walletId: 'missing',
                  source: BitcoinSyncSource.electrum,
                )
                as Err)
            .failure,
        isA<WalletNotFoundFailure>(),
      );
      verifyZeroInteractions(servers);
    },
  );

  test('unknown stored sources fail closed before any script request', () async {
    await db.customStatement(
      "UPDATE wallet_metadatas SET bitcoin_sync_source = 'unknown' WHERE id = ?",
      [_id],
    );
    var scriptRequests = 0;
    await expectLater(
      guard.runExclusive<void>(
        const WalletSourceKey(_id, 'bitcoin', 'mainnet'),
        (_) async {
          scriptRequests++;
        },
        kind: WalletOperationKind.synchronize,
      ),
      throwsFormatException,
    );
    expect(scriptRequests, 0);
    expect(await repository.getWallet(_id, sync: true), isA<Err>());
    verifyZeroInteractions(servers);
  });

  test('reactive wallet registry isolates unavailable source rows', () async {
    await db.customStatement(
      "UPDATE wallet_metadatas SET bitcoin_sync_source = 'future-source' WHERE id = ?",
      [_id],
    );
    final wallets = await metadata.watchSyncPolicies().first;
    expect(
      wallets.map((wallet) => wallet.id),
      unorderedEquals([_other, _liquid]),
    );
    await expectLater(metadata.fetch(_id), throwsFormatException);
  });

  test(
    'an unavailable source isolates one wallet and keeps anonymous guards closed',
    () async {
      await db.customStatement(
        "UPDATE wallet_metadatas SET bitcoin_sync_source = 'future-source' WHERE id = ?",
        [_id],
      );
      final result = await repository.getWallets();
      expect(result, isA<Ok<List<Wallet>, WalletFailure>>());
      if (result case Ok(:final value)) {
        expect(
          value.map((wallet) => wallet.id),
          unorderedEquals([_other, _liquid]),
        );
      }
      expect(await repository.getWallet(_id), isA<Err>());
      var requested = false;
      await expectLater(
        CbfPrivacyGuard(metadata).runUnattributedElectrum(() async {
          requested = true;
        }),
        throwsFormatException,
      );
      expect(requested, isFalse);
      verifyZeroInteractions(servers);
    },
  );

  test(
    'creation returns the persisted policy after a conflicting upsert',
    () async {
      final seed = Seed.mnemonic(
        mnemonicWords: const [],
        bytes: Uint8List.fromList(List.generate(32, (index) => index)),
        masterFingerprint: 'deadbeef',
      );
      final first = await repository.createWallet(
        seed: seed,
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        birthday: WalletBirthday(DateTime.utc(2020)),
      );
      expect(
        await repository.updateBitcoinSyncSettings(
          walletId: first.id,
          source: BitcoinSyncSource.compactBlockFilters,
          birthday: WalletBirthday(DateTime.utc(2019)),
        ),
        isA<Ok>(),
      );
      final returned = await repository.createWallet(
        seed: seed,
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
      );
      final stored = await metadata.fetch(first.id);
      expect(returned.bitcoinSyncSource, stored?.bitcoinSyncSource);
      expect(returned.birthday, stored?.birthday);
      expect(returned.birthday, DateTime.utc(2019));
      verifyZeroInteractions(servers);
    },
  );

  test(
    'prospective CBF creation with sync enabled makes no Electrum request',
    () async {
      const xpub =
          'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';
      await expectLater(
        repository.importWatchOnlyXpub(
          xpub: xpub,
          network: Network.bitcoinMainnet,
          scriptType: ScriptType.bip84,
          label: 'public',
          bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
          sync: true,
        ),
        throwsA(isA<BitcoinSyncSourceUnavailableException>()),
      );
      expect(await metadata.fetchAll(), hasLength(3));
      verifyZeroInteractions(servers);
    },
  );

  test(
    'stale foreground entities and sync reads cannot fall back to Electrum',
    () async {
      final staleWallet =
          (await repository.getWallet(_id) as Ok).value as Wallet;
      expect(
        await update.execute(
          walletId: _id,
          source: BitcoinSyncSource.compactBlockFilters,
        ),
        isA<Ok>(),
      );
      await expectLater(
        repository.sync(staleWallet),
        throwsA(isA<BitcoinSyncSourceUnavailableException>()),
      );
      final read = await repository.getWallet(_id, sync: true);
      expect((read as Err).failure, isA<WalletSyncSourceUnavailableFailure>());
      await metadata.delete(_other);
      final all = await repository.getWallets(onlyBitcoin: true, sync: true);
      expect((all as Err).failure, isA<WalletSyncSourceUnavailableFailure>());
      verifyZeroInteractions(servers);
    },
  );

  test(
    'a queued settings update cannot revive a concurrently deleted wallet',
    () async {
      const key = WalletSourceKey(_id, 'bitcoin', 'mainnet');
      final admitted = Completer<void>();
      final release = Completer<void>();
      final deleting = coordinator.delegate.runExclusive<void>(key, (
        session,
      ) async {
        admitted.complete();
        await release.future;
        await metadata.delete(_id);
        session.retire();
      }, kind: WalletOperationKind.delete);
      await admitted.future;
      final setting = update.execute(
        walletId: _id,
        source: BitcoinSyncSource.compactBlockFilters,
      );
      await coordinator.setterQueued.future;
      release.complete();
      await deleting;
      expect((await setting as Err).failure, isA<WalletNotFoundFailure>());
      expect(await metadata.fetch(_id), isNull);
      await expectLater(
        coordinator.delegate.runExclusive<void>(key, (_) async {}),
        throwsStateError,
      );
      verifyZeroInteractions(servers);
    },
  );

  for (final kind in [
    WalletOperationKind.synchronize,
    WalletOperationKind.discover,
  ]) {
    test('queued $kind checks the source after the setter commits', () async {
      const key = WalletSourceKey(_id, 'bitcoin', 'mainnet');
      final admitted = Completer<void>();
      final release = Completer<void>();
      final holding = coordinator.delegate.runExclusive<void>(key, (_) async {
        admitted.complete();
        await release.future;
      });
      await admitted.future;
      final setting = update.execute(
        walletId: _id,
        source: BitcoinSyncSource.compactBlockFilters,
      );
      await coordinator.setterQueued.future;
      var scriptRequests = 0;
      final job = guard.runExclusive<void>(
        key,
        (_) async {
          scriptRequests++;
        },
        kind: kind,
        priority: WalletOperationPriority.background,
        timeout: null,
      );
      final rejected = expectLater(
        job,
        throwsA(isA<BitcoinSyncSourceUnavailableException>()),
      );
      release.complete();
      await holding;
      expect(await setting, isA<Ok>());
      await rejected;
      expect(scriptRequests, 0);
      expect(await repository.getWallet(_id), isA<Ok>());
      verifyZeroInteractions(servers);
    });
  }

  test(
    'source and birthday save together and survive stale metadata writes',
    () async {
      final stale = await metadata.fetch(_id);
      expect(stale, isNotNull);
      final birthday = WalletBirthday(DateTime.utc(2019, 3));
      expect(
        await repository.updateBitcoinSyncSettings(
          walletId: _id,
          source: BitcoinSyncSource.compactBlockFilters,
          birthday: birthday,
        ),
        isA<Ok>(),
      );
      if (stale == null) return;
      await metadata.store(stale.copyWith(label: 'Backup completed'));
      final saved = await metadata.fetch(_id);
      expect(saved?.bitcoinSyncSource, BitcoinSyncSource.compactBlockFilters);
      expect(saved?.birthday, birthday.dateTime);
      verifyZeroInteractions(servers);
    },
  );

  for (final (descriptor, type) in [
    ('pkh(public/0/*)', BitcoinSyncScriptType.preSegwit),
    ('tr(public/0/*)', BitcoinSyncScriptType.taproot),
  ]) {
    test(
      'earlier-only $type cannot request history before its unknown floor',
      () async {
        const id = 'wpkh([aabbccdd/84h/0h/0h])';
        await metadata.store(
          _metadata(
            id,
          ).copyWith(externalPublicDescriptor: descriptor, birthday: null),
        );
        final settings = await repository.getSyncSettings(id);
        switch (settings) {
          case Ok(:final value):
            expect(value.scanScriptType, type);
          case Err():
            fail('Expected local settings');
        }
        expect(
          await repository.updateBitcoinSyncSettings(
            walletId: id,
            source: BitcoinSyncSource.compactBlockFilters,
            birthday: WalletBirthday(
              type == BitcoinSyncScriptType.preSegwit
                  ? DateTime.utc(2015)
                  : DateTime.utc(2016),
            ),
            earlierOnly: true,
          ),
          isA<Err>(),
        );
        expect((await metadata.fetch(id))?.birthday, isNull);
        verifyZeroInteractions(servers);
      },
    );
  }

  test(
    'earlier-only settings preserve history and reject equal or later months',
    () async {
      final original = await metadata.fetch(_id);
      for (final date in [
        DateTime.utc(2020),
        DateTime.utc(2020, 1, 2),
        DateTime.utc(2021),
      ]) {
        expect(
          await repository.updateBitcoinSyncSettings(
            walletId: _id,
            source: BitcoinSyncSource.electrum,
            birthday: WalletBirthday(date),
            earlierOnly: true,
          ),
          isA<Err>(),
        );
        expect(await metadata.fetch(_id), original);
      }
      final earlier = WalletBirthday(DateTime.utc(2019, 12));
      expect(
        await repository.updateBitcoinSyncSettings(
          walletId: _id,
          source: BitcoinSyncSource.electrum,
          birthday: earlier,
          earlierOnly: true,
        ),
        isA<Ok>(),
      );
      final saved = await metadata.fetch(_id);
      expect(saved?.id, original?.id);
      expect(saved?.birthday, earlier.dateTime);
      verifyZeroInteractions(bdk);
      verifyZeroInteractions(servers);
    },
  );

  test(
    'an earlier-only request cannot restore an obsolete Electrum choice',
    () async {
      expect(
        await update.execute(
          walletId: _id,
          source: BitcoinSyncSource.compactBlockFilters,
        ),
        isA<Ok>(),
      );
      expect(
        await repository.updateBitcoinSyncSettings(
          walletId: _id,
          source: BitcoinSyncSource.electrum,
          birthday: WalletBirthday(DateTime.utc(2019, 12)),
          earlierOnly: true,
        ),
        isA<Ok>(),
      );
      final saved = await metadata.fetch(_id);
      expect(saved?.bitcoinSyncSource, BitcoinSyncSource.compactBlockFilters);
      expect(saved?.birthday, DateTime.utc(2019, 12));
      verifyZeroInteractions(servers);
    },
  );
}
