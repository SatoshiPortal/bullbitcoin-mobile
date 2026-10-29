import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:async/async.dart' show StreamQueue;
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet_sync/data/wallet_sync_status_repository_impl.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_status.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_options_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _Settings extends Mock implements SettingsRepository {}

class _Wallets extends Mock implements WalletMetadataDatasource {}

class _Sync extends Mock implements WalletTransactionSyncFacade {}

class _Metadata extends Fake
    implements WalletSyncMetadataPort, WalletCbfMetadataPort {
  bool complete = false;
  final relayStates = <WalletNetworkKey, Map<String, CbfRelayState>>{};
  @override
  Future<Map<String, CbfRelayState>> readCbfRelayStates(
    WalletNetworkKey key,
  ) async => Map.of(relayStates[key] ?? {});
  @override
  Future<void> stageCbfTransaction(WalletNetworkKey key, String txid) async {
    relayStates
        .putIfAbsent(key, () => {})
        .putIfAbsent(txid, () => CbfRelayState.notBroadcast);
  }

  @override
  Future<void> writeCbfRelayState(
    WalletNetworkKey key,
    String txid,
    CbfRelayState state,
  ) async {
    final states = relayStates.putIfAbsent(key, () => {});
    if (states[txid] != CbfRelayState.relayed) states[txid] = state;
  }

  @override
  Future<bool> isCbfDiscoveryComplete(
    WalletNetworkKey key,
    String policy,
  ) async => complete;
  @override
  Future<DateTime?> readLastSuccessfulSyncAt(WalletNetworkKey key) async =>
      DateTime.utc(2026, 10, 27);
}

const _id = 'wpkh([deadbeef/84h/0h/0h])';
const _key = WalletNetworkKey(_id, 'bitcoin', 'mainnet');
const _settings = SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'CAD',
);
WalletMetadataModel _wallet() => WalletMetadataModel(
  id: _id,
  masterFingerprint: 'deadbeef',
  xpubFingerprint: 'deadbeef',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'public',
  externalPublicDescriptor: 'public/0/*',
  internalPublicDescriptor: 'public/1/*',
  signer: Signer.none,
  isDefault: false,
  birthday: DateTime.utc(2020),
  bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
);
String _policy() {
  final checkpoint = const ResolveBitcoinSyncCheckpointUsecase().execute(
    network: BitcoinNetwork.mainnet,
    birthday: DateTime.utc(2020),
    now: DateTime.now().toUtc(),
  );
  if (checkpoint case Ok(:final value)) {
    return BdkCbfConfiguration(
      externalPublicDescriptor: 'public/0/*',
      internalPublicDescriptor: 'public/1/*',
      isTestnet: false,
      databaseFilePath: '',
      checkpoint: value,
    ).scanPolicyFingerprint;
  }
  throw StateError('public fixture checkpoint');
}

BitcoinSyncProgress _progress(
  BitcoinSyncPhase phase, {
  String? policy,
  bool recovery = true,
  int operationId = 1,
}) => BitcoinSyncProgress(
  key: _key,
  phase: phase,
  policyFingerprint: policy ?? _policy(),
  isRecovery: recovery,
  operationId: operationId,
  startHeight: 100,
  reachedHeight: 150,
  targetHeight: 200,
  fraction: phase == BitcoinSyncPhase.done ? 1 : 0.5,
);

void main() {
  late SqliteDatabase db;
  late WalletMetadataDatasource wallets;
  late _Settings settings;
  late _Sync sync;
  late _Metadata metadata;
  late WalletSyncStatusRepositoryImpl repository;
  late StreamController<BitcoinSyncProgress> progress;
  late StreamController<WalletTransactionSyncState> states;
  setUpAll(() {
    registerFallbackValue(const ListLocalTransactionsRequest(_key));
  });
  setUp(() async {
    db = SqliteDatabase(NativeDatabase.memory());
    wallets = WalletMetadataDatasource(sqlite: db);
    await wallets.store(_wallet());
    settings = _Settings();
    sync = _Sync();
    metadata = _Metadata();
    progress = StreamController.broadcast();
    states = StreamController.broadcast();
    when(() => settings.fetch()).thenAnswer((_) async => _settings);
    when(
      () => sync.watchBitcoinSyncProgress(_key),
    ).thenAnswer((_) => progress.stream);
    when(() => sync.watchWalletState(_key)).thenAnswer((_) => states.stream);
    when(
      () => sync.listLocal(any()),
    ).thenAnswer((_) async => Ok(WalletTransactionPage([], null, 1)));
    repository = WalletSyncStatusRepositoryImpl(
      wallets: wallets,
      settings: settings,
      sync: sync,
      metadata: metadata,
    );
  });
  tearDown(() async {
    await repository.dispose();
    await progress.close();
    await states.close();
    await db.close();
  });
  Future<StreamQueue<WalletSyncStatus>> watch() async {
    final queue = StreamQueue(repository.watch(_id));
    addTearDown(queue.cancel);
    return queue;
  }

  test(
    'initial incompleteness comes from durable policy, never chain height',
    () async {
      final queue = await watch();
      expect((await queue.next).incomplete, isTrue);
      progress.add(_progress(BitcoinSyncPhase.checkingBlocks));
      expect((await queue.next).incomplete, isTrue);
      progress.add(_progress(BitcoinSyncPhase.done));
      expect((await queue.next).incomplete, isFalse);
    },
  );
  test(
    'completed recovery remains complete when reopening without progress',
    () async {
      metadata.complete = true;
      final queue = await watch();
      final status = await queue.next;
      expect(status.incomplete, isFalse);
      expect(status.progress, isNull);
      expect(status.lastSuccessfulSync, DateTime.utc(2026, 10, 27));
    },
  );
  test('saved source changes are visible before recovery finishes', () async {
    await wallets.updateBitcoinSyncSource(_id, BitcoinSyncSource.electrum);
    final queue = await watch();
    expect((await queue.next).isPrivate, isFalse);
    await wallets.updateBitcoinSyncSource(
      _id,
      BitcoinSyncSource.compactBlockFilters,
    );
    repository.invalidate(_id);
    final status = await queue.next;
    expect(status.isPrivate, isTrue);
    expect(status.incomplete, isTrue);
  });
  test(
    'old-policy and Electrum replay cannot relabel the current transport',
    () async {
      when(() => sync.watchBitcoinSyncProgress(_key)).thenAnswer(
        (_) => Stream.value(
          _progress(BitcoinSyncPhase.done, policy: 'old-policy'),
        ),
      );
      final events = <WalletSyncStatus>[];
      final sub = repository.watch(_id).listen(events.add);
      addTearDown(sub.cancel);
      await pumpEventQueue(times: 30);
      expect(events, hasLength(1));
      expect(events.last.incomplete, isTrue);
      await wallets.updateBitcoinSyncSource(_id, BitcoinSyncSource.electrum);
      repository.invalidate(_id);
      await pumpEventQueue(times: 30);
      expect(events.last.isPrivate, isFalse);
      expect(events.last.progress, isNull);
    },
  );
  test('early failures survive a pending reload and remain typed', () async {
    final loaded = Completer<SettingsEntity>();
    when(() => settings.fetch()).thenAnswer((_) => loaded.future);
    final events = <WalletSyncStatus>[];
    final sub = repository.watch(_id).listen(events.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    repository.reportFailure(_id, const WalletSyncTorFailure());
    loaded.complete(_settings);
    await pumpEventQueue(times: 30);
    expect(events.last.failure, isA<WalletSyncTorFailure>());
  });
  test(
    'failures outside the retry command are observed with freshness',
    () async {
      final queue = await watch();
      await queue.next;
      states.add(
        WalletStateFailed(
          null,
          const CbfNoPeersFailure(),
          DateTime.utc(2026, 10, 26),
        ),
      );
      final status = await queue.next;
      expect(status.failure, isA<WalletSyncNoPeersFailure>());
      expect(status.lastSuccessfulSync, DateTime.utc(2026, 10, 26));
    },
  );
  test('a later payment clears the empty recovery notice', () async {
    final events = <WalletSyncStatus>[];
    final subscription = repository.watch(_id).listen(events.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue(times: 30);
    progress.add(_progress(BitcoinSyncPhase.done));
    await pumpEventQueue(times: 30);
    expect(events.last.emptyRecovery, isTrue);
    when(() => sync.listLocal(any())).thenAnswer(
      (_) async => Ok(WalletTransactionPage([_Observation()], null, 2)),
    );
    progress.add(
      _progress(BitcoinSyncPhase.done, recovery: false, operationId: 2),
    );
    await pumpEventQueue(times: 30);
    expect(events.last.emptyRecovery, isFalse);
  });

  test('empty recovery is found when ready arrives before done', () async {
    final queue = await watch();
    await queue.next;
    states.add(WalletStateReady(1, DateTime.utc(2026, 10, 28)));
    await queue.next;
    progress.add(_progress(BitcoinSyncPhase.done));
    expect((await queue.next).incomplete, isFalse);
    expect((await queue.next).emptyRecovery, isTrue);
  });
  test('dispose stops preferences polling with an active listener', () {
    fakeAsync((clock) {
      final localWallets = _Wallets();
      when(() => localWallets.fetch(_id)).thenAnswer((_) async => _wallet());
      final local = WalletSyncStatusRepositoryImpl(
        wallets: localWallets,
        settings: settings,
        sync: sync,
        metadata: metadata,
      );
      final subscription = local.watch(_id).listen((_) {});
      try {
        clock.flushMicrotasks();
        verify(() => settings.fetch()).called(1);
        unawaited(local.dispose());
        clock.flushMicrotasks();
        clearInteractions(settings);
        clock.elapse(const Duration(minutes: 2));
        verifyNever(() => settings.fetch());
      } finally {
        unawaited(subscription.cancel());
        clock.flushMicrotasks();
      }
    });
  });
}

class _Observation extends Fake implements WalletTransactionObservation {}
