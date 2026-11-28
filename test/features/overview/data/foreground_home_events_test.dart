import 'dart:async';
import 'dart:io';

import 'package:electrum/electrum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/silent.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

import '../support/overview_home_harness.dart';

final class _GatedConnection implements WalletConnectionPort {
  final gate = Completer<void>();
  int calls = 0;

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    calls++;
    await gate.future;
    return Ok(
      const SyncCompletion(SyncMode.revealedScripts, Duration.zero) as T,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real foreground start and finish drive Home without reading catalogue at start', () async {
    final directory = await Directory.systemTemp.createTemp(
      'home-sync-events-',
    );
    final connection = _GatedConnection();
    const id = 'wpkh([aabbccdd/84h/1h/0h])';
    final key = WalletKey(id: id, network: BitcoinNetwork.testnet);
    final descriptor = BitcoinWalletDescriptor(
      key: key,
      scriptType: ScriptType.bip84,
      origin: id,
      externalDescriptor: 'wpkh(public)',
      internalDescriptor: 'wpkh(change)',
    );
    final engine = ElectrumSync(
      connections: connection,
      documentsDirectory: () async => directory.path,
      readRevision: (_) async => const Err(SyncNotFoundFailure()),
    );
    final source = FakeOverviewSource();
    final pass = FakeHomeSync();
    final amounts = FakeAmountDisplayPreferences();
    final swaps = FakeOngoingSwaps();
    final silent = FakeSilent();
    final controller = OverviewHomeController(
      catalogue: source,
      sync: pass,
      amountDisplay: OverviewAmountDisplay(amounts),
      ongoingSwaps: swaps,
      swapServerCheck: FakeSwapServerCheck(),
      readBackupWarning: () async => false,
      readPhysicalBackup: (_) async => false,
      proxyNeedsAttention: () async => false,
      silentHome: SilentHomeObservation(silent),
      syncStarted: engine.runsStarted.map(
        (event) => (key: event.key, runId: event.runId),
      ),
      syncFinished: engine.finished.map((event) => event.key),
      electrumResults: ElectrumSyncResult.watch(engine.finished).map(
        (event) => (
          key: event.key,
          runId: event.runId,
          isLiquid: event.isLiquid,
          success: event.success,
        ),
      ),
    );
    addTearDown(() async {
      if (!connection.gate.isCompleted) connection.gate.complete();
      await controller.close();
      await source.close();
      await pass.close();
      await amounts.close();
      await directory.delete(recursive: true);
    });
    source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet(id, network: BitcoinNetwork.testnet, balanceSat: 100),
      ]),
    );
    await flushEvents();
    final snapshotsBefore = source.snapshots;
    final started = engine.started.first;
    final finished = engine.finished.first;
    final result = ElectrumSyncResult.watch(engine.finished).first;
    final pending = ForegroundWalletSynchronization(engine).execute(descriptor);
    expect(await started, key);
    await flushEvents();
    expect(connection.calls, 1);
    expect(controller.current.rows.single.isSyncing, isTrue);
    expect(source.snapshots, snapshotsBefore);
    connection.gate.complete();
    expect(await pending, isA<Ok>());
    expect((await finished).key, key);
    expect((await result).success, isTrue);
    await flushEvents();
    expect(controller.current.rows.single.isSyncing, isFalse);
  });
}
