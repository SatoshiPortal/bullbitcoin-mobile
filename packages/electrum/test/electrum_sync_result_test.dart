import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  test('reachability ignores contention and deferred scans only', () async {
    final bitcoin = WalletKey(id: 'btc', network: BitcoinNetwork.mainnet);
    final liquid = WalletKey(id: 'lbtc', network: LiquidNetwork.mainnet);
    final events = Stream.fromIterable([
      SyncFinished(
        bitcoin,
        const Err(SyncInitialScanRequiredFailure()),
        runId: 5,
      ),
      SyncFinished(liquid, const Err(SyncBusyFailure()), runId: 6),
      SyncFinished(bitcoin, const Err(SyncConnectionFailure()), runId: 7),
      SyncFinished(
        liquid,
        const Ok(SyncCompletion(SyncMode.liquid, Duration.zero)),
        runId: 8,
      ),
    ]);
    final results = await ElectrumSyncResult.watch(events)
        .map((event) => (event.key, event.runId, event.isLiquid, event.success))
        .toList();
    expect(results, [(bitcoin, 7, false, false), (liquid, 8, true, true)]);
  });
}
