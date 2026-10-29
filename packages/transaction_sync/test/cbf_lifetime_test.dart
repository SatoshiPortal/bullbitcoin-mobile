import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  for (final durable in [false, true]) {
    test(
      'native hold preserves ${durable ? 'durable' : 'memory'} exclusion after typed result',
      () async {
        final directory = await Directory.systemTemp.createTemp('cbf-hold-');
        final WalletSourceOperationCoordinator coordinator = durable
            ? DurableWalletSourceOperationCoordinator(
                databasePath: '${directory.path}/coordinator.sqlite',
              )
            : InMemoryWalletSourceOperationCoordinator();
        const key = WalletSourceKey('public-test', 'bitcoin', 'mainnet');
        final terminated = Completer<void>();
        final failure = await coordinator.runExclusive(key, (session) async {
          expect(session, isA<WalletSourceLifetimeSession>());
          (session as WalletSourceLifetimeSession).retainUntil(
            terminated.future,
          );
          return const CoordinationTimeoutFailure();
        });
        expect(failure, isA<CoordinationTimeoutFailure>());
        var entered = false;
        final second = coordinator.runExclusive(key, (_) async {
          entered = true;
          return 2;
        });
        await coordinator.runExclusive(
          const WalletSourceKey('other', 'bitcoin', 'mainnet'),
          (_) async {},
        );
        expect(entered, isFalse);
        terminated.complete();
        expect(await second, 2);
        await directory.delete(recursive: true);
      },
    );
  }
}
