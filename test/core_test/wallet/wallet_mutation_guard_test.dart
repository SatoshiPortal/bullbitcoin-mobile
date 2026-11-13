import 'dart:async';

import 'package:bb_mobile/core/wallet/domain/wallet_mutation_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes independent work and permits awaited reentrancy', () async {
    final guard = WalletMutationGuard();
    final entered = Completer<void>();
    final finish = Completer<void>();
    final events = <String>[];
    final first = guard.exclusive(() async {
      events.add('first');
      await guard.exclusive(() async => events.add('nested'));
      entered.complete();
      await finish.future;
    });
    await entered.future;
    final second = guard.exclusive(() async => events.add('second'));
    await Future<void>.delayed(Duration.zero);
    expect(events, ['first', 'nested']);
    finish.complete();
    await Future.wait([first, second]);
    expect(events, ['first', 'nested', 'second']);
  });

  test(
    'masked external callbacks wait while their registering owner is active',
    () async {
      final guard = WalletMutationGuard();
      final fire = Completer<void>();
      final events = <String>[];
      late Future<void> callback;
      await guard.exclusive(() async {
        events.add('owner');
        callback = guard.withoutReentrance(
          () => fire.future.then(
            (_) => guard.exclusive(() async => events.add('external')),
          ),
        );
        fire.complete();
        await Future<void>.delayed(Duration.zero);
        expect(events, ['owner']);
      });
      await callback;
      expect(events, ['owner', 'external']);
    },
  );

  test('an error releases the queue for subsequent work', () async {
    final guard = WalletMutationGuard();
    await expectLater(
      guard.exclusive<void>(() async => throw StateError('failure')),
      throwsStateError,
    );
    expect(await guard.exclusive(() async => 42), 42);
  });

  test(
    'a callback inherited from an expired zone must join the queue',
    () async {
      final guard = WalletMutationGuard();
      final startDetached = Completer<void>();
      final detachedDone = Completer<void>();
      final block = Completer<void>();
      final entered = Completer<void>();
      final events = <String>[];
      await guard.exclusive(() async {
        // Simulate an accidentally detached callback after its owner has exited.
        unawaited(
          startDetached.future.then((_) async {
            await guard.exclusive(() async => events.add('detached'));
            detachedDone.complete();
          }),
        );
      });
      final holder = guard.exclusive(() async {
        events.add('holder');
        entered.complete();
        await block.future;
      });
      await entered.future;
      startDetached.complete();
      await Future<void>.delayed(Duration.zero);
      expect(events, ['holder']);
      block.complete();
      await holder;
      await detachedDone.future;
      expect(events, ['holder', 'detached']);
    },
  );
}
