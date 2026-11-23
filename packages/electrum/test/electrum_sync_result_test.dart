import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  test('reachability ignores contention and deferred scans only', () async {
    final bitcoin = WalletKey(id: 'btc', network: BitcoinNetwork.mainnet);
    final liquid = WalletKey(id: 'lbtc', network: LiquidNetwork.mainnet);
    final events = Stream.fromIterable([
      SyncFinished(bitcoin, const Err(SyncInitialScanRequiredFailure())),
      SyncFinished(liquid, const Err(SyncBusyFailure())),
      SyncFinished(bitcoin, const Err(SyncConnectionFailure())),
      SyncFinished(
        liquid,
        const Ok(SyncCompletion(SyncMode.liquid, Duration.zero)),
      ),
    ]);
    final results = await ElectrumSyncResult.watch(events)
        .map((event) => (event.isLiquid, event.success))
        .toList();
    expect(results, [(false, false), (true, true)]);
  });
}
