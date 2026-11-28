import 'dart:async';

import 'package:electrum/electrum.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  test('a source error does not end later reachability events', () async {
    final key = WalletKey(id: 'wallet', network: BitcoinNetwork.mainnet);
    final events = StreamController<SyncFinished>();
    addTearDown(events.close);
    final errors = <Object>[];
    final results = <ElectrumSyncResult>[];
    final subscription = ElectrumSyncResult.watch(events.stream)
        .listen(results.add, onError: (Object error) => errors.add(error));
    addTearDown(subscription.cancel);

    final error = Exception('source failed');
    events.addError(error);
    events.add(
      SyncFinished(
        key,
        const Ok(SyncCompletion(SyncMode.revealedScripts, Duration.zero)),
        runId: 42,
      ),
    );
    await events.close();

    expect(errors, [same(error)]);
    expect(results, hasLength(1));
    expect(results.single.key, key);
    expect(results.single.runId, 42);
    expect(results.single.isLiquid, isFalse);
    expect(results.single.success, isTrue);
  });
}
