import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';
import 'package:test/test.dart';

final class _FailingConnection implements WalletConnectionPort {
  int calls = 0;

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    calls++;
    if (calls == 1) {
      throw Exception('electrum.example.com:50002 private certificate');
    }
    return const Err(SyncConnectionFailure());
  }
}

void main() {
  test(
    'recoverable failures yield sanitized finishes and later runs',
    () async {
      final connection = _FailingConnection();
      final sync = ElectrumSync(
        connections: connection,
        documentsDirectory: () async => '/nonexistent',
        readRevision: (_) async => const Err(SyncNotFoundFailure()),
      );
      final key = WalletKey(id: 'wallet', network: BitcoinNetwork.mainnet);
      final descriptor = BitcoinWalletDescriptor(
        key: key,
        scriptType: ScriptType.bip84,
        origin: 'test',
        externalDescriptor: 'wpkh(public)',
        internalDescriptor: 'wpkh(change)',
      );
      final starts = <SyncStarted>[];
      final finishes = <SyncFinished>[];
      final errors = <Object>[];
      final startSubscription = sync.runsStarted.listen(
        starts.add,
        onError: (Object error) => errors.add(error),
      );
      final finishSubscription = sync.finished.listen(
        finishes.add,
        onError: (Object error) => errors.add(error),
      );
      addTearDown(startSubscription.cancel);
      addTearDown(finishSubscription.cancel);

      final first = await sync.execute(descriptor);
      final second = await sync.execute(descriptor);
      await Future<void>.delayed(Duration.zero);

      expect(first, isA<Err<SyncCompletion, SyncFailure>>());
      expect(second, isA<Err<SyncCompletion, SyncFailure>>());
      expect(starts, hasLength(2));
      expect(finishes, hasLength(2));
      expect(errors, isEmpty);
      expect(starts.map((event) => event.key), [key, key]);
      expect(finishes.map((event) => event.key), [key, key]);
      expect(
        finishes.map((event) => event.runId),
        starts.map((event) => event.runId),
      );
      expect(starts[1].runId, greaterThan(starts[0].runId));
      final failures = finishes.map((event) => (event.result as Err).failure);
      expect(failures.first, isA<SyncStorageFailure>());
      expect(failures.last, isA<SyncConnectionFailure>());
      for (final failure in failures) {
        expect(failure.toString(), isNot(contains('electrum.example.com')));
        expect(failure.toString(), isNot(contains('private certificate')));
      }
    },
  );
}
