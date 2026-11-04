import 'package:bb_mobile/wallet_sync_connection_adapters.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart' as sync;
import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:wallet/wallet.dart';
import 'package:bb_mobile/features/transactions/data/wallet_transaction_repository_impl.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transaction_sync/transaction_sync.dart'
    show
        InMemoryWalletSourceOperationCoordinator,
        WalletOperationKind,
        WalletOperationPriority,
        WalletSourceKey,
        WalletSourceOperationCoordinator,
        WalletSourceSession;

class _MockWalletSnapshotReader extends Mock implements WalletSnapshotReader {}

class _MockWalletCatalogPort extends Mock implements WalletCatalogPort {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

class _MockElectrumServersPort extends Mock implements ElectrumServersPort {}

class _ControllableElectrumServersPort implements ElectrumServersPort {
  int calls = 0;

  @override
  Future<T> runWithFallback<T>({
    required ElectrumServerNetwork network,
    required Future<T> Function(ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  }) {
    calls++;
    return operation(
      const ElectrumConnection(
        url: 'electrum.example',
        retry: 0,
        timeout: 30,
        stopGap: 20,
        validateDomain: true,
        isCustom: false,
      ),
    );
  }
}

class _CountingCoordinator implements WalletSourceOperationCoordinator {
  int calls = 0;

  @override
  Future<T> runExclusive<T>(
    WalletSourceKey key,
    Future<T> Function(WalletSourceSession session) operation, {
    Duration? timeout = const Duration(seconds: 30),
    bool allowRetired = false,
    WalletOperationKind kind = WalletOperationKind.refresh,
    WalletOperationPriority priority = WalletOperationPriority.foreground,
  }) {
    calls++;
    return operation(_TestSession());
  }
}

class _TestSession implements WalletSourceSession {
  @override
  bool get isClosed => false;

  @override
  void ensureOpen() {}

  @override
  void retire() {}

  @override
  void reactivate() {}

  @override
  Future<void> close() async {}
}

const _walletId = 'wpkh([73c5da0a/84h/1h/0h])';
const _otherWalletId = 'wpkh([deadbeef/84h/1h/0h])';
const _liquidWalletId = 'elwpkh([73c5da0a/84h/1h/0h])';

void main() {
  const metadata = WalletMetadata(
    id: _walletId,
    masterFingerprint: '73c5da0a',
    xpubFingerprint: 'deadbeef',
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    xpub: 'tpub-test',
    externalPublicDescriptor: 'wpkh(external)',
    internalPublicDescriptor: 'wpkh(internal)',
    signer: SignerEntity.local,
    isDefault: true,
  );
  final transactionModel = WalletTransactionModel(
    txId: 'tx-id',
    isIncoming: true,
    amountSat: 1000,
    feeSat: 100,
    vsize: 200,
    inputs: [
      TransactionInputModel.bitcoin(
        txId: 'tx-id',
        vin: 1,
        isOwn: false,
        previousTxId: 'previous-id',
        previousTxVout: 0,
      ),
    ],
    outputs: [
      TransactionOutputModel.bitcoin(
        txId: 'tx-id',
        vout: 0,
        isOwn: true,
        value: BigInt.from(1000),
        scriptPubkey: Uint8List(0),
        address: 'tb1-address',
      ),
    ],
    isLiquid: false,
    isTestnet: true,
    isRbf: false,
  );

  setUpAll(() {
    registerFallbackValue(_TestSession());
    registerFallbackValue(metadata);
    registerFallbackValue(
      const WalletModel.publicBdk(
        id: _walletId,
        externalDescriptor: 'wpkh(external)',
        internalDescriptor: 'wpkh(internal)',
        isTestnet: true,
      ),
    );
    registerFallbackValue(
      const ElectrumConnection(
        url: 'electrum.example',
        retry: 0,
        timeout: 30,
        stopGap: 20,
        validateDomain: true,
        isCustom: false,
      ),
    );
    registerFallbackValue(const _FallbackWalletConnection());
  });

  test('pushes down tx lookup and batches label reads', () async {
    final metadataDatasource = _MockWalletCatalogPort();
    final labelsFacade = _MockLabelsFacade();
    final bdkDatasource = _MockBdkWalletDatasource();
    final lwkDatasource = _MockLwkWalletDatasource();
    final repository = WalletTransactionRepositoryImpl(
      walletMetadataDatasource: metadataDatasource,
      labelsFacade: labelsFacade,
      reader: WalletTransactionReader(
        snapshots: _MockWalletSnapshotReader(),
        bdkWalletTransactionDatasource: bdkDatasource,
        lwkWalletTransactionDatasource: lwkDatasource,
        serversPort: WalletSyncConnectionAdapter(_MockElectrumServersPort()),
        coordinator: InMemoryWalletSourceOperationCoordinator(),
      ),
    );
    final labels = [
      Label(
        id: 1,
        type: LabelType.input,
        label: 'input label',
        reference: 'tx-id:1',
      ),
      Label(
        id: 2,
        type: LabelType.output,
        label: 'output label',
        reference: 'tx-id:0',
      ),
      Label.addr(id: 3, address: 'tb1-address', label: 'address label'),
      Label.tx(id: 4, transactionId: 'tx-id', label: 'transaction label'),
    ];

    when(
      () => metadataDatasource.fetch(_walletId),
    ).thenAnswer((_) async => metadata);
    when(() => labelsFacade.fetchAll()).thenAnswer((_) async => labels);
    when(
      () => bdkDatasource.getTransactions(
        wallet: any(named: 'wallet'),
        txId: 'tx-id',
        toAddress: any(named: 'toAddress'),
      ),
    ).thenAnswer((_) async => [transactionModel]);

    final transaction = await repository.getWalletTransaction(
      'tx-id',
      walletId: _walletId,
    );

    if (transaction == null) fail('transaction not found');
    expect(transaction.inputs.single.labels, ['input label']);
    expect(transaction.outputs.single.labels.map((label) => label.label), [
      'output label',
    ]);
    expect(
      transaction.outputs.single.addressLabels.map((label) => label.label),
      ['address label'],
    );
    expect(transaction.labels.map((label) => label.label), [
      'transaction label',
    ]);
    await repository.getWalletTransactions(
      walletId: _walletId,
      txId: 'tx-id',
      toAddress: 'tb1-target',
    );
    verify(
      () => bdkDatasource.getTransactions(
        wallet: any(named: 'wallet'),
        txId: 'tx-id',
        toAddress: 'tb1-target',
      ),
    ).called(1);
    verify(() => labelsFacade.fetchAll()).called(2);
    verifyNever(() => labelsFacade.fetchByReference(any()));
    verifyNever(
      () => lwkDatasource.getTransactions(
        wallet: any(named: 'wallet'),
        txId: any(named: 'txId'),
        toAddress: any(named: 'toAddress'),
      ),
    );
  });

  test('serializes operations for the same BDK wallet key', () async {
    final metadataDatasource = _MockWalletCatalogPort();
    final bdkDatasource = _MockBdkWalletDatasource();
    final labelsFacade = _MockLabelsFacade();
    final snapshots = _MockWalletSnapshotReader();
    final repository = _repository(
      metadataDatasource: metadataDatasource,
      bdkDatasource: bdkDatasource,
      labelsFacade: labelsFacade,
      snapshots: snapshots,
    );
    final entered = Completer<void>();
    final release = Completer<void>();
    var calls = 0;

    when(
      () => metadataDatasource.fetch(_walletId),
    ).thenAnswer((_) async => metadata);
    when(() => labelsFacade.fetchAll()).thenAnswer((_) async => []);
    when(
      () => snapshots.read(
        wallet: any(named: 'wallet'),
        session: any(named: 'session'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        entered.complete();
        await release.future;
      }
      return Ok(_emptySnapshot());
    });

    final first = repository.getWalletTransactions(walletId: _walletId);
    await entered.future;
    final second = repository.getWalletTransactions(walletId: _walletId);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    release.complete();
    await Future.wait([first, second]);
    expect(calls, 2);
  });

  test(
    'allows operations for different BDK wallet keys to enter independently',
    () async {
      final metadataDatasource = _MockWalletCatalogPort();
      final bdkDatasource = _MockBdkWalletDatasource();
      final labelsFacade = _MockLabelsFacade();
      final snapshots = _MockWalletSnapshotReader();
      final repository = _repository(
        metadataDatasource: metadataDatasource,
        bdkDatasource: bdkDatasource,
        labelsFacade: labelsFacade,
        snapshots: snapshots,
      );
      final firstMetadata = metadata;
      final secondMetadata = metadata.copyWith(id: _otherWalletId);
      final entered = <String>{};
      final firstEntered = Completer<void>();
      final secondEntered = Completer<void>();
      final release = Completer<void>();

      when(
        () => metadataDatasource.fetch(_walletId),
      ).thenAnswer((_) async => firstMetadata);
      when(
        () => metadataDatasource.fetch(_otherWalletId),
      ).thenAnswer((_) async => secondMetadata);
      when(() => labelsFacade.fetchAll()).thenAnswer((_) async => []);
      when(
        () => snapshots.read(
          wallet: any(named: 'wallet'),
          session: any(named: 'session'),
        ),
      ).thenAnswer((invocation) async {
        final wallet = invocation.namedArguments[#wallet] as WalletMetadata;
        entered.add(wallet.id);
        if (wallet.id == _walletId) {
          firstEntered.complete();
        } else {
          secondEntered.complete();
        }
        await release.future;
        return Ok(_emptySnapshot());
      });

      final first = repository.getWalletTransactions(walletId: _walletId);
      await firstEntered.future;
      final second = repository.getWalletTransactions(walletId: _otherWalletId);
      await secondEntered.future;
      expect(entered, {_walletId, _otherWalletId});
      release.complete();
      await Future.wait([first, second]);
    },
  );

  test(
    'releases the key after a failed operation so a retry can progress',
    () async {
      final metadataDatasource = _MockWalletCatalogPort();
      final bdkDatasource = _MockBdkWalletDatasource();
      final labelsFacade = _MockLabelsFacade();
      final snapshots = _MockWalletSnapshotReader();
      final repository = _repository(
        metadataDatasource: metadataDatasource,
        bdkDatasource: bdkDatasource,
        labelsFacade: labelsFacade,
        snapshots: snapshots,
      );
      var calls = 0;
      when(
        () => metadataDatasource.fetch(_walletId),
      ).thenAnswer((_) async => metadata);
      when(() => labelsFacade.fetchAll()).thenAnswer((_) async => []);
      when(
        () => snapshots.read(
          wallet: any(named: 'wallet'),
          session: any(named: 'session'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw StateError('failed source');
        return Ok(_emptySnapshot());
      });

      await expectLater(
        repository.getWalletTransactions(walletId: _walletId),
        throwsStateError,
      );
      await repository.getWalletTransactions(walletId: _walletId);
      expect(calls, 2);
    },
  );

  test('keeps sync and read atomic for the same BDK wallet key', () async {
    final metadataDatasource = _MockWalletCatalogPort();
    final bdkDatasource = _MockBdkWalletDatasource();
    final labelsFacade = _MockLabelsFacade();
    final snapshots = _MockWalletSnapshotReader();
    final serversPort = _ControllableElectrumServersPort();
    final repository = _repository(
      metadataDatasource: metadataDatasource,
      bdkDatasource: bdkDatasource,
      labelsFacade: labelsFacade,
      snapshots: snapshots,
      serversPort: serversPort,
    );
    final syncEntered = Completer<void>();
    final release = Completer<void>();
    final events = <String>[];
    var syncCalls = 0;
    var readCalls = 0;

    when(
      () => metadataDatasource.fetch(_walletId),
    ).thenAnswer((_) async => metadata);
    when(() => labelsFacade.fetchAll()).thenAnswer((_) async => []);
    when(
      () => bdkDatasource.sync(
        wallet: any(named: 'wallet'),
        electrumServer: any(named: 'electrumServer'),
      ),
    ).thenAnswer((_) async {
      syncCalls++;
      events.add('sync-$syncCalls');
      if (syncCalls == 1) {
        syncEntered.complete();
        await release.future;
      }
    });
    when(
      () => snapshots.read(
        wallet: any(named: 'wallet'),
        session: any(named: 'session'),
      ),
    ).thenAnswer((_) async {
      readCalls++;
      events.add('read-$readCalls');
      return Ok(_emptySnapshot());
    });

    final first = repository.getWalletTransactions(
      walletId: _walletId,
      sync: true,
    );
    await syncEntered.future;
    final second = repository.getWalletTransactions(
      walletId: _walletId,
      sync: true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(serversPort.calls, 1);
    expect(syncCalls, 1);
    expect(readCalls, 0);
    release.complete();
    await Future.wait([first, second]);

    expect(events, ['sync-1', 'read-1', 'sync-2', 'read-2']);
  });

  test(
    'synchronizes and reads BDK before propagating a label-store failure',
    () async {
      final metadataDatasource = _MockWalletCatalogPort();
      final bdkDatasource = _MockBdkWalletDatasource();
      final labelsFacade = _MockLabelsFacade();
      final snapshots = _MockWalletSnapshotReader();
      final serversPort = _ControllableElectrumServersPort();
      final repository = _repository(
        metadataDatasource: metadataDatasource,
        bdkDatasource: bdkDatasource,
        labelsFacade: labelsFacade,
        snapshots: snapshots,
        serversPort: serversPort,
      );
      final events = <String>[];

      when(
        () => metadataDatasource.fetch(_walletId),
      ).thenAnswer((_) async => metadata);
      when(
        () => labelsFacade.fetchAll(),
      ).thenThrow(StateError('labels failed'));
      when(
        () => bdkDatasource.sync(
          wallet: any(named: 'wallet'),
          electrumServer: any(named: 'electrumServer'),
        ),
      ).thenAnswer((_) async => events.add('sync'));
      when(
        () => snapshots.read(
          wallet: any(named: 'wallet'),
          session: any(named: 'session'),
        ),
      ).thenAnswer((_) async {
        events.add('read');
        return Ok(_emptySnapshot());
      });

      await expectLater(
        repository.getWalletTransactions(walletId: _walletId, sync: true),
        throwsStateError,
      );

      expect(events, ['sync', 'read']);
    },
  );

  test('exact lookup uses one coordinated operation', () async {
    final metadataDatasource = _MockWalletCatalogPort();
    final bdkDatasource = _MockBdkWalletDatasource();
    final labelsFacade = _MockLabelsFacade();
    final coordinator = _CountingCoordinator();
    final repository = _repository(
      metadataDatasource: metadataDatasource,
      bdkDatasource: bdkDatasource,
      labelsFacade: labelsFacade,
      coordinator: coordinator,
    );
    when(
      () => metadataDatasource.fetch(_walletId),
    ).thenAnswer((_) async => metadata);
    when(() => labelsFacade.fetchAll()).thenAnswer((_) async => []);
    when(
      () => bdkDatasource.getTransactions(
        wallet: any(named: 'wallet'),
        txId: 'tx-id',
        toAddress: any(named: 'toAddress'),
      ),
    ).thenAnswer((_) async => [transactionModel]);

    final transaction = await repository.getWalletTransaction(
      'tx-id',
      walletId: _walletId,
    );

    expect(transaction, isNotNull);
    expect(coordinator.calls, 1);
  });

  test('keeps LWK sync and read atomic for the same wallet key', () async {
    final metadataDatasource = _MockWalletCatalogPort();
    final lwkDatasource = _MockLwkWalletDatasource();
    final labelsFacade = _MockLabelsFacade();
    final snapshots = _MockWalletSnapshotReader();
    final serversPort = _ControllableElectrumServersPort();
    final repository = _repository(
      metadataDatasource: metadataDatasource,
      bdkDatasource: _MockBdkWalletDatasource(),
      lwkDatasource: lwkDatasource,
      labelsFacade: labelsFacade,
      snapshots: snapshots,
      serversPort: serversPort,
    );
    final liquidMetadata = metadata.copyWith(id: _liquidWalletId);
    final syncEntered = Completer<void>();
    final release = Completer<void>();
    final events = <String>[];
    var syncCalls = 0;
    var readCalls = 0;

    when(
      () => metadataDatasource.fetch(_liquidWalletId),
    ).thenAnswer((_) async => liquidMetadata);
    when(() => labelsFacade.fetchAll()).thenAnswer((_) async => []);
    when(
      () => lwkDatasource.sync(
        wallet: any(named: 'wallet'),
        electrumServer: any(named: 'electrumServer'),
      ),
    ).thenAnswer((_) async {
      syncCalls++;
      events.add('sync-$syncCalls');
      if (syncCalls == 1) {
        syncEntered.complete();
        await release.future;
      }
    });
    when(
      () => snapshots.read(
        wallet: any(named: 'wallet'),
        session: any(named: 'session'),
      ),
    ).thenAnswer((_) async {
      readCalls++;
      events.add('read-$readCalls');
      return Ok(_emptySnapshot());
    });

    final first = repository.getWalletTransactions(
      walletId: _liquidWalletId,
      sync: true,
    );
    await syncEntered.future;
    final second = repository.getWalletTransactions(
      walletId: _liquidWalletId,
      sync: true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(syncCalls, 1);
    expect(readCalls, 0);
    expect(serversPort.calls, 1);
    release.complete();
    await Future.wait([first, second]);

    expect(events, ['sync-1', 'read-1', 'sync-2', 'read-2']);
  });

  test(
    'retains the ephemeral Liquid URL only in an exact detail result',
    () async {
      final metadataDatasource = _MockWalletCatalogPort();
      final lwkDatasource = _MockLwkWalletDatasource();
      final labelsFacade = _MockLabelsFacade();
      final repository = _repository(
        metadataDatasource: metadataDatasource,
        bdkDatasource: _MockBdkWalletDatasource(),
        lwkDatasource: lwkDatasource,
        labelsFacade: labelsFacade,
      );
      when(
        () => metadataDatasource.fetch(_liquidWalletId),
      ).thenAnswer((_) async => metadata.copyWith(id: _liquidWalletId));
      when(() => labelsFacade.fetchAll()).thenAnswer((_) async => []);
      when(
        () => lwkDatasource.getTransactions(
          wallet: any(named: 'wallet'),
          txId: 'tx-id',
          toAddress: any(named: 'toAddress'),
        ),
      ).thenAnswer(
        (_) async => [
          transactionModel.copyWith(
            isLiquid: true,
            inputs: [],
            outputs: [],
            unblindedUrl: 'https://example.invalid/fixture',
          ),
        ],
      );
      final transaction = await repository.getWalletTransaction(
        'tx-id',
        walletId: _liquidWalletId,
      );
      expect(transaction?.unblindedUrl, 'https://example.invalid/fixture');
      expect(transaction?.amountSat, transactionModel.amountSat);
    },
  );

  test(
    'pushes down exact LWK lookup without requesting full history',
    () async {
      final metadataDatasource = _MockWalletCatalogPort();
      final lwkDatasource = _MockLwkWalletDatasource();
      final labelsFacade = _MockLabelsFacade();
      final repository = _repository(
        metadataDatasource: metadataDatasource,
        bdkDatasource: _MockBdkWalletDatasource(),
        lwkDatasource: lwkDatasource,
        labelsFacade: labelsFacade,
      );
      final liquidMetadata = metadata.copyWith(id: _liquidWalletId);

      when(
        () => metadataDatasource.fetch(_liquidWalletId),
      ).thenAnswer((_) async => liquidMetadata);
      when(() => labelsFacade.fetchAll()).thenAnswer((_) async => []);
      when(
        () => lwkDatasource.getTransactions(
          wallet: any(named: 'wallet'),
          txId: 'tx-id',
          toAddress: any(named: 'toAddress'),
        ),
      ).thenAnswer((_) async => []);

      await repository.getWalletTransaction('tx-id', walletId: _liquidWalletId);

      verify(
        () => lwkDatasource.getTransactions(
          wallet: any(named: 'wallet'),
          txId: 'tx-id',
          toAddress: any(named: 'toAddress'),
        ),
      ).called(1);
      verifyNever(
        () => lwkDatasource.getTransactions(
          wallet: any(named: 'wallet'),
          txId: null,
          toAddress: any(named: 'toAddress'),
        ),
      );
    },
  );
}

WalletTransactionRepositoryImpl _repository({
  required _MockWalletCatalogPort metadataDatasource,
  required _MockBdkWalletDatasource bdkDatasource,
  _MockLwkWalletDatasource? lwkDatasource,
  required _MockLabelsFacade labelsFacade,
  WalletSourceOperationCoordinator? coordinator,
  WalletSnapshotReader? snapshots,
  ElectrumServersPort? serversPort,
}) {
  return WalletTransactionRepositoryImpl(
    walletMetadataDatasource: metadataDatasource,
    labelsFacade: labelsFacade,
    reader: WalletTransactionReader(
      snapshots: snapshots ?? _MockWalletSnapshotReader(),
      bdkWalletTransactionDatasource: bdkDatasource,
      lwkWalletTransactionDatasource:
          lwkDatasource ?? _MockLwkWalletDatasource(),
      serversPort: WalletSyncConnectionAdapter(
        serversPort ?? _MockElectrumServersPort(),
      ),
      coordinator: coordinator ?? InMemoryWalletSourceOperationCoordinator(),
    ),
  );
}

sync.WalletTransactionSnapshot _emptySnapshot() =>
    sync.WalletTransactionSnapshot(
      key: const sync.WalletNetworkKey(_walletId, 'bitcoin', 'testnet'),
      revision: 1,
      contentFingerprint: 'empty',
      transactions: const [],
      observedAt: DateTime.utc(2026),
      lastSuccessfulSyncAt: null,
      sourceKind: 'bdk_electrum',
      capabilities: const {},
      sourceTip: null,
      complete: true,
      evidenceLevel: sync.WalletEvidenceLevel.localSourceState,
    );

/// Mocktail fallback for the connection the wallet package receives.
final class _FallbackWalletConnection implements WalletConnectionPort {
  const _FallbackWalletConnection();

  @override
  String get url => 'electrum.example';

  @override
  int get retry => 0;

  @override
  int get effectiveTimeout => 30;

  @override
  int get stopGap => 20;

  @override
  bool get validateDomain => true;

  @override
  String? get socks5 => null;
}
