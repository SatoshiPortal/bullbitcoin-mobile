import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show SeedReferences;
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/domain/usecases/delete_secret_usecase.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';
import 'dart:io';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_transaction_repository_impl.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart'
    show Signer;
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' show Wallet;
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/data/foreground_wallet_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _Swaps extends Mock implements BoltzSwapRepository {}

class _Native extends Mock implements WalletNativeLifecycle {}

class _WatchOnly extends Mock implements satoshifier.WatchOnlyDescriptor {}

class _Descriptor extends Mock implements satoshifier.Descriptor {}

class _Labels extends Mock implements LabelsFacade {}

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Bdk extends Mock implements BdkWalletDatasource {}

class _Lwk extends Mock implements LwkWalletDatasource {}

final class _Policy implements WalletConnectionPolicy {
  TransactionSyncFailure? failure;
  int calls = 0;
  @override
  Future<Result<T, TransactionSyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, TransactionSyncFailure>> Function(
      WalletConnection,
    )
    operation,
    required bool Function(TransactionSyncFailure) mayRetry,
  }) async {
    calls++;
    final error = failure;
    if (error != null) return Err(error);
    return Ok(
      const SyncCompletion(SyncMode.revealedScripts, Duration.zero) as T,
    );
  }
}

void main() {
  const id = 'wpkh([aabbccdd/84h/1h/0h])';
  final row = WalletMetadataModel(
    id: id,
    masterFingerprint: 'aabbccdd',
    xpubFingerprint: 'aabbccdd',
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    xpub: 'public',
    externalPublicDescriptor: 'wpkh(public)',
    internalPublicDescriptor: 'wpkh(change)',
    signer: Signer.none,
    isDefault: false,
  );
  registerFallbackValue(
    const WalletModel.publicBdk(
      id: id,
      externalDescriptor: 'wpkh(public)',
      internalDescriptor: 'wpkh(change)',
      isTestnet: true,
    ),
  );
  registerFallbackValue(row);
  late Directory directory;
  late _Policy policy;
  late _Metadata metadata;
  late _Bdk bdk;
  late WalletRepository repository;
  late ForegroundWalletSync bridge;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('foreground-sync-');
    policy = _Policy();
    metadata = _Metadata();
    bdk = _Bdk();
    when(() => metadata.fetch(id)).thenAnswer((_) async => row);
    when(() => metadata.store(any())).thenAnswer((_) async {});
    when(() => metadata.insert(any())).thenAnswer((_) async {});
    when(() => bdk.getBalance(wallet: any(named: 'wallet'))).thenAnswer(
      (_) async => BalanceModel(
        confirmedSat: BigInt.zero,
        immatureSat: BigInt.zero,
        trustedPendingSat: BigInt.zero,
        untrustedPendingSat: BigInt.zero,
        spendableSat: BigInt.zero,
        totalSat: BigInt.zero,
      ),
    );
    bridge = ForegroundWalletSync(
      ElectrumSync(
        connections: policy,
        documentsDirectory: () async => directory.path,
      ),
    );
    repository = WalletRepository(
      walletMetadataDatasource: metadata,
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: _Lwk(),
      synchronize: bridge.synchronize,
      isSyncing: bridge.isSyncing,
      syncStarted: bridge.started,
      syncFinished: bridge.finished,
      electrumSyncResultStream: bridge.results,
    );
  });

  tearDown(() => directory.deleteSync(recursive: true));

  for (final deleteWallet in [false, true]) {
    test(
      'invalid-origin local row protects seed; deleteWallet=$deleteWallet',
      () async {
        final storage = FakeSecureStoragePlatform()..install();
        final secrets = Secrets(scratchDirectory: () async => directory.path);
        final secret =
            await secrets.import(
                  words: [...List.filled(11, 'abandon'), 'about'],
                )
                as Ok<Secret, SecretFailure>;
        final local = row.copyWith(
          signer: Signer.local,
          masterFingerprint: secret.value.id.hex,
        );
        final remaining = local.copyWith(id: 'invalid');
        when(() => metadata.fetch(id)).thenAnswer((_) async => local);
        when(() => metadata.fetchAll()).thenAnswer((_) async => [remaining]);
        final native = _Native();
        when(() => native.delete(any())).thenAnswer((_) async {});
        when(() => native.catalogDeleted(any())).thenAnswer((_) async {});
        when(() => metadata.delete(id)).thenAnswer((_) async {});
        final guardedRepository = WalletRepository(
          native: native,
          walletMetadataDatasource: metadata,
          bdkWalletDatasource: bdk,
          lwkWalletDatasource: _Lwk(),
          synchronize: bridge.synchronize,
          isSyncing: bridge.isSyncing,
          syncStarted: bridge.started,
          syncFinished: bridge.finished,
          electrumSyncResultStream: bridge.results,
        );
        if (deleteWallet) {
          final swaps = _Swaps();
          when(
            () => swaps.getOngoingSwaps(walletId: id),
          ).thenAnswer((_) async => []);
          expect(
            await DeleteWalletUsecase(
              walletRepository: guardedRepository,
              seedReferences: SeedReferences(guardedRepository),
              swapRepository: swaps,
              secrets: secrets,
            ).execute(walletId: id),
            isA<Ok>(),
          );
        } else {
          final result = await DeleteSecretUsecase(
            secrets: secrets,
            seedReferences: SeedReferences(guardedRepository),
          ).execute(secret.value.id);
          expect(result, isA<Err>());
        }
        expect(
          storage.entries.keys.where((key) => key.startsWith('seed_')),
          hasLength(1),
        );
      },
    );
  }

  test(
    'custody query ignores origins, balances and nonlocal fingerprints',
    () async {
      when(() => metadata.fetchAll()).thenAnswer(
        (_) async => [
          row.copyWith(
            id: 'invalid',
            signer: Signer.local,
            masterFingerprint: 'AABBCCDD',
          ),
          row.copyWith(signer: Signer.none, masterFingerprint: 'invalid'),
          row.copyWith(signer: Signer.remote, masterFingerprint: '11223344'),
        ],
      );
      final result = await repository.getCustodyFingerprints();
      expect(result, isA<Ok>());
      expect((result as Ok).value, {Fingerprint('aabbccdd')});
      verifyNever(() => bdk.getBalance(wallet: any(named: 'wallet')));
    },
  );

  test('custody query refuses an incomplete local fingerprint set', () async {
    when(() => metadata.fetchAll()).thenAnswer(
      (_) async => [
        row.copyWith(signer: Signer.local),
        row.copyWith(signer: Signer.local, masterFingerprint: 'invalid'),
      ],
    );
    expect(await repository.getCustodyFingerprints(), isA<Err>());
    when(
      () => metadata.fetchAll(),
    ).thenThrow(const FormatException('unreadable row'));
    expect(await repository.getCustodyFingerprints(), isA<Err>());
  });

  test('invalid catalog origin does not hide a healthy wallet', () async {
    when(
      () => metadata.fetchAll(),
    ).thenAnswer((_) async => [row.copyWith(id: 'invalid'), row]);
    final result = await repository.getWallets();
    expect(result, isA<Ok>());
    if (result case Ok(:final value)) {
      expect(value.map((wallet) => wallet.id), [id]);
    }
  });

  test(
    'one unavailable wallet does not hide the rest of the catalog',
    () async {
      final other = row.copyWith(id: 'wpkh([11223344/84h/1h/0h])');
      when(() => metadata.fetchAll()).thenAnswer((_) async => [row, other]);
      when(() => bdk.getBalance(wallet: any(named: 'wallet'))).thenAnswer((
        invocation,
      ) async {
        final model = invocation.namedArguments[#wallet] as WalletModel;
        if (model.id == id) throw const FileSystemException('unavailable');
        return BalanceModel(
          confirmedSat: BigInt.one,
          immatureSat: BigInt.zero,
          trustedPendingSat: BigInt.zero,
          untrustedPendingSat: BigInt.zero,
          spendableSat: BigInt.one,
          totalSat: BigInt.one,
        );
      });
      final result = await repository.getWallets();
      expect(result, isA<Ok>());
      if (result case Ok(:final value)) {
        expect(value, hasLength(2));
        expect(value.first.balanceSat, isNull);
        expect(value.first.unavailable, isTrue);
        expect(value.last.unavailable, isFalse);
        expect(value.last.balanceSat, BigInt.one);
        expect(WalletState(wallets: value).totalBalance(), isNull);
      }
    },
  );

  test(
    'foreground use case reaches the new operation and legacy events',
    () async {
      final wallet =
          (await repository.getWallet(id) as Ok<Wallet, WalletFailure>).value;
      final started = repository.walletSyncStartedStream.first;
      final finished = repository.walletSyncFinishedStream.first;
      final result = repository.electrumSyncResultStream.first;
      await SyncWalletUsecase(walletRepository: repository).execute(wallet);
      expect(policy.calls, 1);
      expect((await started).id, id);
      expect((await finished).id, id);
      expect((await result).success, isTrue);
    },
  );

  test(
    'single-wallet usecase forwards discovery through the repository',
    () async {
      final requests = <bool>[];
      final repository = WalletRepository(
        walletMetadataDatasource: metadata,
        bdkWalletDatasource: bdk,
        lwkWalletDatasource: _Lwk(),
        synchronize: (metadata, {bool discover = false}) async =>
            requests.add(discover),
        isSyncing: ({String? walletId}) => false,
        syncStarted: const Stream.empty(),
        syncFinished: const Stream.empty(),
        electrumSyncResultStream: const Stream.empty(),
      );
      final wallet =
          (await repository.getWallet(id) as Ok<Wallet, WalletFailure>).value;
      final usecase = SyncWalletUsecase(walletRepository: repository);
      await usecase.execute(wallet);
      await usecase.execute(wallet, discover: true);
      expect(requests, [false, true]);
    },
  );

  test(
    'unavailable repair is a storage failure without legacy reader healing',
    () async {
      policy.failure = const TransactionSyncNeedsRepairFailure();
      await expectLater(
        bridge.synchronize(row),
        throwsA(isA<WalletStorageFailure>()),
      );
    },
  );

  test('unexpected policy failure settles the finished event', () async {
    final sync = ElectrumSync(
      connections: _ThrowingPolicy(),
      documentsDirectory: () async => directory.path,
    );
    final finished = sync.finished.first;
    final result = await sync.execute(
      BitcoinWalletDescriptor(
        key: WalletKey(id: id, network: BitcoinNetwork.testnet),
        scriptType: ScriptType.bip84,
        origin: id,
        externalDescriptor: 'wpkh(public)',
        internalDescriptor: 'wpkh(change)',
      ),
    );
    expect(result, isA<Err<SyncCompletion, TransactionSyncFailure>>());
    expect((await finished).result, same(result));
    expect(sync.isSyncing(), isFalse);
  });

  test(
    'writer busy skips the call and retains its visible unsuccessful result',
    () async {
      policy.failure = const TransactionSyncBusyFailure();
      final result = bridge.results.first;
      await bridge.synchronize(row);
      expect((await result).success, isFalse);
    },
  );

  test('transaction reads delegate sync to the same operation', () async {
    when(
      () => bdk.getTransactions(wallet: any(named: 'wallet'), toAddress: null),
    ).thenAnswer((_) async => []);
    final transactions = WalletTransactionRepositoryImpl(
      walletMetadataDatasource: metadata,
      labelsFacade: _Labels(),
      bdkWalletTransactionDatasource: bdk,
      lwkWalletTransactionDatasource: _Lwk(),
      synchronize: bridge.synchronize,
    );
    expect(
      await transactions.getWalletTransactions(walletId: id, sync: true),
      isEmpty,
    );
    expect(policy.calls, 1);
    verify(
      () => bdk.getTransactions(wallet: any(named: 'wallet'), toAddress: null),
    ).called(1);
  });

  test('sync:true reads preserve connection versus storage failure', () async {
    policy.failure = const TransactionSyncConnectionFailure();
    final connection = await repository.getWallet(id, sync: true);
    expect(connection, isA<Err<Wallet, WalletFailure>>());
    if (connection case Err(:final failure)) {
      expect(failure, isA<WalletSyncFailure>());
    }
    policy.failure = const TransactionSyncStorageFailure();
    final storage = await repository.getWallet(id, sync: true);
    if (storage case Err(:final failure)) {
      expect(failure, isA<WalletStorageFailure>());
    }
    expect(storage, isA<Err<Wallet, WalletFailure>>());
    verifyNever(() => bdk.getBalance(wallet: any(named: 'wallet')));
  });
  test(
    'descriptor import persists catalog then creates offline before sync',
    () async {
      final descriptor = _Descriptor();
      when(
        () => descriptor.network,
      ).thenReturn(satoshifier.Network.bitcoinTestnet);
      when(
        () => descriptor.derivation,
      ).thenReturn(satoshifier.Derivation.bip84);
      when(() => descriptor.external).thenReturn('wpkh(public)');
      when(() => descriptor.internal).thenReturn('wpkh(change)');
      when(() => descriptor.pubkey).thenReturn(
        'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj',
      );
      when(() => descriptor.fingerprint).thenReturn('aabbccdd');
      final watchOnly = _WatchOnly();
      when(() => watchOnly.descriptor).thenReturn(descriptor);
      when(() => metadata.fetchAll()).thenAnswer((_) async => []);
      when(() => metadata.fetch(id)).thenAnswer((_) async => null);
      var provisioned = false;
      final native = _Native();
      when(() => native.prepareCreate(any())).thenAnswer((_) async {
        verifyNever(() => metadata.insert(any()));
      });
      when(() => native.create(any())).thenAnswer((_) async {
        verify(() => metadata.insert(any())).called(1);
        verifyNever(() => bdk.getBalance(wallet: any(named: 'wallet')));
        provisioned = true;
      });
      var synchronized = false;
      final originalBalance = await bdk.getBalance(
        wallet: const WalletModel.publicBdk(
          id: id,
          externalDescriptor: 'wpkh(public)',
          internalDescriptor: 'wpkh(change)',
          isTestnet: true,
        ),
      );
      when(() => bdk.getBalance(wallet: any(named: 'wallet'))).thenAnswer((
        _,
      ) async {
        expect(provisioned, isTrue);
        return originalBalance;
      });
      clearInteractions(bdk);
      final importing = WalletRepository(
        native: native,
        walletMetadataDatasource: metadata,
        bdkWalletDatasource: bdk,
        lwkWalletDatasource: _Lwk(),
        synchronize: (value, {bool discover = false}) async {
          expect(provisioned, isTrue);
          expect(value.id, id);
          verify(() => native.create(any())).called(1);
          synchronized = true;
        },
        isSyncing: ({String? walletId}) => false,
        syncStarted: const Stream.empty(),
        syncFinished: const Stream.empty(),
        electrumSyncResultStream: const Stream.empty(),
      );
      final wallet = await importing.importDescriptor(
        watchOnlyDescriptor: WatchOnlyDescriptorEntity(
          watchOnlyDescriptor: watchOnly,
        ),
        sync: true,
      );
      expect(synchronized, isTrue);
      expect(wallet.id, id);
      verify(() => bdk.getBalance(wallet: any(named: 'wallet'))).called(1);
    },
  );
}

final class _ThrowingPolicy implements WalletConnectionPolicy {
  @override
  Future<Result<T, TransactionSyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, TransactionSyncFailure>> Function(
      WalletConnection,
    )
    operation,
    required bool Function(TransactionSyncFailure) mayRetry,
  }) async {
    throw StateError('sensitive error detail');
  }
}
