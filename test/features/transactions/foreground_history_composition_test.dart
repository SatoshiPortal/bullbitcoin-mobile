import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:labels/labels.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:swaps/order_swaps.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart';
import 'package:transactions/routes.dart';
import 'package:transactions/setup.dart';
import 'package:transactions/transactions.dart';

class _Inventory extends Mock implements WalletInventory {}

class _Labels extends Mock implements Labels {}

class _Swaps extends Mock implements ReadOrderSwaps {}

final class _Connection implements WalletConnectionPort {
  final calls = <String>[];
  SyncFailure? failure;

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    calls.add('sync');
    final error = failure;
    if (error != null) return Err(error);
    return Ok(
      const SyncCompletion(SyncMode.revealedScripts, Duration.zero) as T,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const id = 'wpkh([aabbccdd/84h/1h/0h])';
  final key = WalletKey(id: id, network: BitcoinNetwork.testnet);
  final descriptor = BitcoinWalletDescriptor(
    key: key,
    scriptType: ScriptType.bip84,
    origin: id,
    externalDescriptor: 'wpkh(public)',
    internalDescriptor: 'wpkh(change)',
  );
  late Directory directory;
  late _Connection connection;
  late Transactions transactions;
  late GetIt services;
  late List<String> reads;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('foreground-history-');
    log = Logger.replace(directory: directory);
    connection = _Connection();
    reads = connection.calls;
    final inventory = _Inventory();
    when(() => inventory.readWallet(id)).thenAnswer(
      (_) async => Ok(
        walletRegistrationForTesting(id: id, network: BitcoinNetwork.testnet),
      ),
    );
    final wallet = await testWallet(key: key);
    final engine = ElectrumSync(
      connections: connection,
      documentsDirectory: () async => directory.path,
      readRevision: (_) async => const Err(SyncNotFoundFailure()),
    );
    final foreground = ForegroundWalletSynchronization(engine);
    services = GetIt.asNewInstance();
    services.registerSingleton<Labels>(_Labels());
    TransactionsFeature.mount(
      services,
      inventory: inventory,
      loadWallet: (requested) async {
        reads.add('history');
        expect(requested, key);
        return Ok(wallet);
      },
      findDescriptor: (requested) async {
        reads.add('descriptor');
        expect(requested, key);
        return Ok(descriptor);
      },
      synchronize: foreground.execute,
      events: WalletHistoryEvents.foreground(
        revisions: const Stream.empty(),
        finished: engine.finished,
        watchSyncPassActivity: () => const Stream.empty(),
        isSyncPassActive: () => false,
      ),
      syncStarted: () => const Stream.empty(),
      syncFinished: () => const Stream.empty(),
      orderSwaps: () => _Swaps(),
      actions: TransactionUiActions(
        openExchange: (_) {},
        openWalletHome: (_) {},
        refreshWallets: (_) async {},
        accelerateOrder: (_, _) => const SizedBox(),
        showReceipt: (_, _) {},
        accelerateWalletTransaction: (_, _) {},
        addressViewer: (_, _) => const SizedBox(),
        orderSwapUnderReview: (_) => const SizedBox(),
      ),
      pollSettlement: (_, {required isActive}) async {},
      scope: (child) => child,
    );
    transactions = services<Transactions>();
  });

  tearDown(() async {
    await services.reset();
    await log.flush();
    await directory.delete(recursive: true);
  });

  test(
    'sync true resolves and synchronizes before reading wallet history',
    () async {
      final result = await transactions.getWalletTransactions(
        walletId: id,
        sync: true,
      );
      expect(result, isA<Ok<List<WalletTransaction>, TransactionFailure>>());
      if (result case Ok(:final value)) expect(value, isEmpty);
      expect(reads, ['descriptor', 'sync', 'history']);
    },
  );

  for (final failure in const <SyncFailure>[
    SyncConnectionFailure(),
    SyncStorageFailure(),
  ]) {
    test('sync true stops before history on ${failure.runtimeType}', () async {
      connection.failure = failure;
      final result = await transactions.getWalletTransactions(
        walletId: id,
        sync: true,
      );
      expect(
        result,
        isA<Err<List<WalletTransaction>, TransactionFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<TransactionAggregationFailure>(),
        ),
      );
      expect(reads, ['descriptor', 'sync']);
      final rows = await log.readLogs();
      expect(
        rows.where((row) => row.contains('Electrum sync failed')),
        hasLength(1),
      );
      expect(
        rows.where((row) => row.contains('\tSEVERE\t')),
        hasLength(failure is SyncStorageFailure ? 1 : 0),
      );
      expect(rows.join('\n'), isNot(contains('Wallet read failed')));
    });
  }
}
