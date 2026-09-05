import 'dart:async';

import 'package:test/test.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

void main() {
  test(
    'operations for one source key wait while independent keys proceed',
    () async {
      final coordinator = InMemoryWalletSourceOperationCoordinator();
      final entered = Completer<void>();
      final release = Completer<void>();
      final first = coordinator.runExclusive(
        const WalletSourceKey('a', 'c', 'n'),
        (session) async {
          entered.complete();
          await release.future;
          return 1;
        },
      );
      await entered.future;
      var secondEntered = false;
      final second = coordinator.runExclusive(
        const WalletSourceKey('a', 'c', 'n'),
        (session) async {
          secondEntered = true;
          return 2;
        },
      );
      expect(
        await coordinator.runExclusive(
          const WalletSourceKey('b', 'c', 'n'),
          (session) async => 3,
        ),
        3,
      );
      expect(secondEntered, isFalse);
      release.complete();
      expect(await first, 1);
      expect(await second, 2);
    },
  );

  test('a timeout reports to the caller but keeps holding the key', () async {
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    const key = WalletSourceKey('a', 'c', 'n');
    final release = Completer<void>();

    final timedOut = coordinator.runExclusive(key, (session) async {
      await release.future;
      return 1;
    }, timeout: const Duration(milliseconds: 20));
    await expectLater(timedOut, throwsA(isA<TimeoutException>()));

    var secondEntered = false;
    final second = coordinator.runExclusive(key, (session) async {
      secondEntered = true;
      return 2;
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      secondEntered,
      isFalse,
      reason: 'the key must stay held until the timed-out operation ends',
    );

    release.complete();
    expect(await second, 2);
    expect(secondEntered, isTrue);
  });

  test('retired source keys reject later operations', () async {
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    const key = WalletSourceKey('a', 'c', 'n');

    await coordinator.runExclusive(key, (session) async {
      session.retire();
    });

    await expectLater(
      coordinator.runExclusive(key, (_) async {}),
      throwsStateError,
    );
  });

  test('an explicitly reactivated source key can be used again', () async {
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    const key = WalletSourceKey('a', 'c', 'n');

    await coordinator.runExclusive(key, (session) async {
      session.retire();
    });
    await coordinator.runExclusive(key, (session) async {
      session.reactivate();
    }, allowRetired: true);
    expect(await coordinator.runExclusive(key, (_) async => 1), 1);
  });

  test('allowRetired does not reactivate a source key by itself', () async {
    final coordinator = InMemoryWalletSourceOperationCoordinator();
    const key = WalletSourceKey('a', 'c', 'n');

    await coordinator.runExclusive(key, (session) async {
      session.retire();
    });
    await coordinator.runExclusive(key, (_) async {}, allowRetired: true);

    await expectLater(
      coordinator.runExclusive(key, (_) async {}),
      throwsStateError,
    );
  });

  test(
    'the session handed to an operation is closed after it completes',
    () async {
      final coordinator = InMemoryWalletSourceOperationCoordinator();
      late WalletSourceSession leaked;
      await coordinator.runExclusive(const WalletSourceKey('a', 'c', 'n'), (
        session,
      ) async {
        leaked = session;
        session.ensureOpen();
        return 0;
      });
      expect(leaked.isClosed, isTrue);
      expect(leaked.ensureOpen, throwsStateError);
    },
  );
}
