import 'package:transactions/testing.dart';
import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';
import 'package:sync/storage.dart' show SyncWalletValuesDatasource;
import 'package:background_tasks/native_sync.dart';

import 'dart:async';

import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';

import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:labels/labels.dart';
import 'package:legacy_storage/app_database.dart' show Signer;
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show Wallet;
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:electrum/electrum.dart' show ElectrumSyncResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' hide Wallet;
import 'package:sync/write.dart';

class _Labels extends Mock implements Labels {}

class _Catalog extends Mock implements WalletCatalogPort {}

class _Metadata extends Mock implements WalletRegistrations {}

class _Values extends Mock implements SyncWalletValuesDatasource {}

class _Inventory extends Mock implements WalletInventory {}

class _History extends Mock implements WalletHistoryDatasource {}

final class _Policy implements WalletConnectionPort {
  SyncFailure? failure;
  int calls = 0;
  Future<void>? gate;
  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    calls++;
    await gate;
    final error = failure;
    if (error != null) return Err(error);
    return Ok(
      const SyncCompletion(SyncMode.revealedScripts, Duration.zero) as T,
    );
  }
}

Future<T> passthroughSessionJoin<T>(Future<T> Function() read) => read();

void main() {
  const id = 'wpkh([aabbccdd/84h/1h/0h])';
  final row = WalletMetadataModel(
    networkCode: 'bitcoinTestnet',
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
  registerFallbackValue(row);
  registerFallbackValue(DateTime.utc(2020));
  registerFallbackValue(WalletSyncBinding.keyFromMetadata(row));
  late Directory directory;
  late _Policy policy;
  late _Metadata metadata;
  late _Values values;
  late WalletRepository repository;
  late _Bridge bridge;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('foreground-sync-');
    policy = _Policy();
    metadata = _Metadata();
    values = _Values();
    when(() => metadata.fetch(id)).thenAnswer((_) async => row);
    when(() => values.getBalance(key: any(named: 'key'))).thenAnswer(
      (_) async => Balances(
        confirmedSat: BigInt.zero,
        immatureSat: BigInt.zero,
        trustedPendingSat: BigInt.zero,
        untrustedPendingSat: BigInt.zero,
        spendableSat: BigInt.zero,
        totalSat: BigInt.zero,
      ),
    );
    bridge = _Bridge(
      ElectrumSync(
        connections: policy,
        documentsDirectory: () async => directory.path,
        readRevision: (_) async => const Err(SyncNotFoundFailure()),
      ),
    );
    repository = WalletRepository(
      walletRegistrations: metadata,
      session: passthroughSessionJoin,
      walletValuesDatasource: values,
      synchronization: bridge.synchronization,
      syncStarted: bridge.started,
      syncFinished: bridge.finished,
    );
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('busy finishes without reporting an Electrum outage', () async {
    policy.failure = const SyncBusyFailure();
    final results = <Object>[];
    final finished = <String>[];
    final resultSubscription = bridge.results.listen(results.add);
    final finishedSubscription = bridge.finished.listen(finished.add);
    try {
      await expectLater(
        bridge.synchronize(row),
        throwsA(isA<WalletSnapshotException>()),
      );
      await pumpEventQueue();
      expect(results, isEmpty);
      expect(finished, [id]);
      policy.failure = const SyncInitialScanRequiredFailure();
      await expectLater(
        bridge.synchronize(row, allowInitialScan: false),
        throwsA(isA<WalletSnapshotException>()),
      );
      await pumpEventQueue();
      expect(results, isEmpty);
      expect(finished, [id, id]);
      policy.failure = const SyncConnectionFailure();
      await expectLater(
        bridge.synchronize(row),
        throwsA(isA<WalletSnapshotException>()),
      );
      await pumpEventQueue();
      expect(results, hasLength(1));
    } finally {
      await resultSubscription.cancel();
      await finishedSubscription.cancel();
    }
  });

  test('invalid catalog origin does not hide a healthy wallet', () async {
    when(() => metadata.fetchAll())
        .thenAnswer((_) async => [row.copyWith(id: 'invalid'), row]);
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
      when(() => values.getBalance(key: any(named: 'key')))
          .thenAnswer((invocation) async {
            final key = invocation.namedArguments[#key] as WalletKey;
            if (key.id == id) throw const FileSystemException('unavailable');
            return Balances(
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
      final result = bridge.results.first;
      await repository.sync(wallet);
      expect(policy.calls, 1);
      expect(await started, id);
      expect((await finished).id, id);
      expect((await result).success, isTrue);
    },
  );

  test('sync start emits without admitting a balance reader', () async {
    final wallet =
        (await repository.getWallet(id) as Ok<Wallet, WalletFailure>).value;
    clearInteractions(values);
    final gate = Completer<void>();
    policy.gate = gate.future;
    final started = repository.walletSyncStartedStream.first;
    final syncing = repository.sync(wallet);
    try {
      await started;
      verifyNever(() => values.getBalance(key: any(named: 'key')));
    } finally {
      gate.complete();
      await syncing;
    }
  });

  for (final reason in SyncReason.values) {
    test(
      'persists started, finished and failed reason=${reason.name}',
      () async {
        log = Logger.replace(directory: directory);
        final wallet =
            (await repository.getWallet(id) as Ok<Wallet, WalletFailure>).value;
        await repository.sync(wallet, reason: reason);
        policy.failure = const SyncConnectionFailure();
        await expectLater(
          repository.sync(wallet, reason: reason),
          throwsA(
            isA<WalletSnapshotException>().having(
              (error) => error.failure,
              'failure',
              isA<SyncConnectionFailure>(),
            ),
          ),
        );
        final rows = (await log.readLogs())
            .where((row) => row.contains('Electrum sync '))
            .toList();
        expect(rows.where((row) => row.contains('started')), hasLength(2));
        expect(rows.where((row) => row.contains('finished')), hasLength(1));
        expect(rows.where((row) => row.contains('failed')), hasLength(1));
        expect(rows, everyElement(contains('reason=${reason.name}')));
        expect(rows.join(), isNot(contains(id)));
      },
    );
  }

  test('background adapter explicitly persists background reason', () async {
    log = Logger.replace(directory: directory);
    final descriptor = BitcoinWalletDescriptor(
      key: WalletKey(id: id, network: BitcoinNetwork.testnet),
      scriptType: ScriptType.bip84,
      origin: id,
      externalDescriptor: 'wpkh(public)',
      internalDescriptor: 'wpkh(change)',
    );
    final catalog = _Catalog();
    when(() => catalog.find(descriptor.key))
        .thenAnswer((_) async => Ok(descriptor));
    final background = BackgroundWalletSyncImpl(
      catalog,
      ElectrumSync(
        connections: policy,
        documentsDirectory: () async => directory.path,
        readRevision: (_) async => const Err(SyncNotFoundFailure()),
      ),
      collectIncoming: false,
    );
    // The policy fixture returns no committed revision, so the adapter rejects it.
    expect(
      await background.synchronize(
        descriptor.key,
        allowInitialScan: false,
        discover: true,
      ),
      isA<Err>(),
    );
    final rows = (await log.readLogs())
        .where((row) => row.contains('Electrum sync '))
        .toList();
    expect(rows, hasLength(2));
    expect(rows, everyElement(contains('reason=background')));
    expect(rows, everyElement(contains('headless=true')));
    expect(rows.first, contains('discovery=true'));
  });

  test(
    'engine joins retain auto and queued discovery retains manual',
    () async {
      log = Logger.replace(directory: directory);
      final gate = Completer<void>();
      policy.gate = gate.future;
      final auto = bridge.synchronize(row);
      await pumpEventQueue();
      final pull = bridge.synchronize(row, reason: SyncReason.pull);
      final manual = bridge.synchronize(
        row,
        discover: true,
        reason: SyncReason.manual,
      );
      await pumpEventQueue();
      expect(policy.calls, 1);
      gate.complete();
      await Future.wait([auto, pull, manual]);
      final rows = (await log.readLogs())
          .where((row) => row.contains('Electrum sync '))
          .toList();
      expect(rows, hasLength(4));
      expect(rows.take(2), everyElement(contains('reason=auto')));
      expect(rows.skip(2), everyElement(contains('reason=manual')));
      expect(policy.calls, 2);
    },
  );

  test(
    'single-wallet usecase forwards discovery and initial-scan policy',
    () async {
      log = Logger.replace(directory: directory);
      final forwarding = _Policy();
      final repository = WalletRepository(
        walletRegistrations: metadata,
        session: passthroughSessionJoin,
        walletValuesDatasource: values,
        synchronization: ForegroundWalletSynchronization(
          ElectrumSync(
            connections: forwarding,
            documentsDirectory: () async => directory.path,
            readRevision: (_) async => const Err(SyncNotFoundFailure()),
          ),
        ),
        syncStarted: const Stream<String>.empty(),
        syncFinished: const Stream<String>.empty(),
      );
      final wallet =
          (await repository.getWallet(id) as Ok<Wallet, WalletFailure>).value;
      await repository.sync(wallet);
      await repository.sync(wallet, discover: true);
      await repository.sync(wallet, allowInitialScan: false);
      expect(forwarding.calls, 3);
      final rows = (await log.readLogs())
          .where((row) => row.contains('Electrum sync started '))
          .toList();
      expect(rows, hasLength(3));
      expect(rows[0], contains('discovery=false allow_initial_scan=true'));
      expect(rows[1], contains('discovery=true allow_initial_scan=true'));
      expect(rows[2], contains('discovery=false allow_initial_scan=false'));
    },
  );

  test(
    'unavailable repair preserves its category without legacy reader healing',
    () async {
      policy.failure = const SyncNeedsRepairFailure();
      await expectLater(
        bridge.synchronize(row),
        throwsA(
          isA<WalletSnapshotException>().having(
            (error) => error.failure,
            'failure',
            isA<SyncNeedsRepairFailure>(),
          ),
        ),
      );
    },
  );

  test(
    'unexpected policy failure settles once and bounds diagnostics',
    () async {
      log = Logger.replace(directory: directory);
      final sync = ElectrumSync(
        connections: _ThrowingPolicy(),
        documentsDirectory: () async => directory.path,
        readRevision: (_) async => const Err(SyncNotFoundFailure()),
      );
      final descriptor = BitcoinWalletDescriptor(
        key: WalletKey(id: id, network: BitcoinNetwork.testnet),
        scriptType: ScriptType.bip84,
        origin: id,
        externalDescriptor: 'wpkh(public)',
        internalDescriptor: 'wpkh(change)',
      );
      final finished = sync.finished.first;
      final result = await sync.execute(descriptor);
      expect(result, isA<Err<SyncCompletion, SyncFailure>>());
      expect((await finished).result, same(result));
      expect(sync.isSyncing(), isFalse);
      expect(await sync.execute(descriptor), isA<Err>());
      expect(
        (await log.readLogs())
            .where((row) => row.split('\t')[1] == 'SEVERE')
            .map((row) => row.split('\t')[2]),
        ['Electrum sync unexpected failure reason=auto'],
      );
    },
  );

  test('writer busy fails through the real foreground usecase', () async {
    policy.failure = const SyncBusyFailure();
    final finished = bridge.finished.first;
    final wallet =
        (await repository.getWallet(id) as Ok<Wallet, WalletFailure>).value;
    await expectLater(
      repository.sync(wallet, discover: true, reason: SyncReason.manual),
      throwsA(
        isA<WalletSnapshotException>().having(
          (error) => error.failure,
          'failure',
          isA<SyncBusyFailure>(),
        ),
      ),
    );
    expect(await finished, id);
  });

  test('transaction reads delegate sync to the same operation', () async {
    final history = _History();
    final inventory = _Inventory();
    when(() => inventory.readWallet(id)).thenAnswer(
      (_) async => Ok(
        walletRegistrationForTesting(id: id, network: BitcoinNetwork.testnet),
      ),
    );
    when(() => history.getTransactions(key: any(named: 'key'), toAddress: null))
        .thenAnswer((_) async => const Ok([]));
    final transactions = WalletTransactionRepositoryImpl(
      inventory: inventory,
      labelsFacade: _Labels(),
      history: history,
      synchronize: (key) => bridge.synchronizeDescriptor(
        WalletSyncBinding.descriptorFromMetadata(row)
            .fold((value) => value, (failure) => fail(failure.logCode)),
      ),
    );
    expect(
      (await transactions.getWalletTransactions(walletId: id, sync: true)).fold(
        (value) => value,
        (failure) => fail(failure.runtimeType.toString()),
      ),
      isEmpty,
    );
    expect(policy.calls, 1);
    verify(
      () => history.getTransactions(key: any(named: 'key'), toAddress: null),
    ).called(1);
  });

  test('sync:true reads preserve connection versus storage failure', () async {
    final directory = Directory.systemTemp.createTempSync('sync-read-logs-');
    await initializeLogging(directory: directory);
    addTearDown(() async {
      await log.flush();
      directory.deleteSync(recursive: true);
    });
    policy.failure = const SyncConnectionFailure();
    final connection = await repository.getWallet(id, sync: true);
    expect(connection, isA<Err<Wallet, WalletFailure>>());
    if (connection case Err(:final failure)) {
      expect(failure, isA<WalletSyncFailure>());
    }
    final connectionLogs = (await log.readLogs()).join('\n');
    expect(connectionLogs, contains('Electrum sync failed'));
    expect(connectionLogs, isNot(contains('SEVERE')));
    expect(connectionLogs, isNot(contains('Wallet sync unavailable')));
    expect(
      (await log.readLogs()).where((row) => row.contains('WARNING')),
      hasLength(1),
    );
    policy.failure = const SyncStorageFailure();
    final storage = await repository.getWallet(id, sync: true);
    if (storage case Err(:final failure)) {
      expect(failure, isA<WalletStorageFailure>());
    }
    expect(storage, isA<Err<Wallet, WalletFailure>>());
    expect(
      (await log.readLogs()).where((row) => row.contains('SEVERE')),
      hasLength(1),
    );
    expect(
      (await log.readLogs()).join('\n'),
      isNot(contains('Wallet read failed')),
    );
    verifyNever(() => values.getBalance(key: any(named: 'key')));
  });
}

final class _ThrowingPolicy implements WalletConnectionPort {
  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    throw const FormatException('sensitive error detail');
  }
}

/// The legacy repository's view of foreground sync: catalog rows resolve to
/// descriptors, then the Sync operation runs.
final class _Bridge {
  final ElectrumSync sync;
  final ForegroundWalletSynchronization synchronization;

  _Bridge(this.sync) : synchronization = ForegroundWalletSynchronization(sync);

  Stream<String> get started => sync.started.map((key) => key.id);
  Stream<String> get finished => sync.finished.map((event) => event.key.id);
  Stream<ElectrumSyncResult> get results =>
      ElectrumSyncResult.watch(sync.finished);

  Future<void> synchronize(
    WalletMetadataModel metadata, {
    bool discover = false,
    bool allowInitialScan = true,
    SyncReason reason = SyncReason.auto,
  }) async {
    switch (WalletSyncBinding.descriptorFromMetadata(metadata)) {
      case Err():
        throw const WalletStorageFailure('Invalid sync descriptor');
      case Ok(:final value):
        WalletSyncBinding.value(
          await synchronization.execute(
            value,
            discover: discover,
            allowInitialScan: allowInitialScan,
            reason: reason,
          ),
        );
    }
  }

  Future<Result<void, SyncFailure>> synchronizeDescriptor(
    PublicWalletDescriptor descriptor, {
    SyncReason reason = SyncReason.auto,
  }) => synchronization.execute(descriptor, reason: reason);
}
