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
  late _Policy policy;
  late _Metadata metadata;
  late _Bdk bdk;
  late WalletRepository repository;
  late ForegroundWalletSync bridge;

  setUp(() {
    policy = _Policy();
    metadata = _Metadata();
    bdk = _Bdk();
    when(() => metadata.fetch(id)).thenAnswer((_) async => row);
    when(() => metadata.store(any())).thenAnswer((_) async {});
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
        documentsDirectory: () async => '/unused',
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
  test('new descriptor import provisions legacy storage before sync', () async {
    final descriptor = _Descriptor();
    when(
      () => descriptor.network,
    ).thenReturn(satoshifier.Network.bitcoinTestnet);
    when(() => descriptor.derivation).thenReturn(satoshifier.Derivation.bip84);
    when(() => descriptor.external).thenReturn('wpkh(public)');
    when(() => descriptor.internal).thenReturn('wpkh(change)');
    when(() => descriptor.pubkey).thenReturn(
      'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj',
    );
    when(() => descriptor.fingerprint).thenReturn('aabbccdd');
    final watchOnly = _WatchOnly();
    when(() => watchOnly.descriptor).thenReturn(descriptor);
    when(() => metadata.fetchAll()).thenAnswer((_) async => []);
    var provisioned = false;
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
      provisioned = true;
      return originalBalance;
    });
    final importing = WalletRepository(
      walletMetadataDatasource: metadata,
      bdkWalletDatasource: bdk,
      lwkWalletDatasource: _Lwk(),
      synchronize: (value) async {
        expect(provisioned, isTrue);
        expect(value.id, id);
        verifyNever(() => metadata.store(any()));
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
    verify(() => metadata.store(any())).called(1);
  });
}
