import 'dart:async';

import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:flutter_test/flutter_test.dart';

/// [BdkFacade.walletLock] itself never touches native BDK/FFI code — it is
/// a plain per-id `Lock` registry — so its serialization guarantee (the
/// property `CbfWalletDatasource._run` and
/// `BdkWalletDatasource.applyUnconfirmedTransaction` both depend on to
/// avoid a same-wallet lost update) is fully testable without constructing
/// a real `bdk.Wallet`.
void main() {
  group('BdkFacade.walletLock', () {
    test('returns the same Lock instance for the same wallet id, so every '
        'subsystem locking on that id actually shares one lock', () {
      final first = BdkFacade.walletLock('wallet-1');
      final second = BdkFacade.walletLock('wallet-1');

      expect(identical(first, second), isTrue);
    });

    test('returns different Lock instances for different wallet ids, so '
        'unrelated wallets never contend with each other', () {
      final walletOne = BdkFacade.walletLock('wallet-1');
      final walletTwo = BdkFacade.walletLock('wallet-2');

      expect(identical(walletOne, walletTwo), isFalse);
    });

    test(
      'serializes two concurrent critical sections for the same wallet id '
      '— the second never starts until the first has fully finished',
      () async {
        final events = <String>[];
        final firstEntered = Completer<void>();

        final firstCall = BdkFacade.walletLock('wallet-serialized')
            .synchronized(() async {
              events.add('first-start');
              firstEntered.complete();
              // Yields control (like the real load→mutate→persist await
              // gaps this lock guards) without releasing the lock.
              await Future<void>.delayed(const Duration(milliseconds: 20));
              events.add('first-end');
            });

        // Only start the second call once we know the first has actually
        // entered its critical section, so this is a genuine "does the
        // second wait" check rather than a race on scheduling order.
        await firstEntered.future;
        final secondCall = BdkFacade.walletLock('wallet-serialized')
            .synchronized(() async {
              events.add('second-start');
            });

        await Future.wait([firstCall, secondCall]);

        expect(events, ['first-start', 'first-end', 'second-start']);
      },
    );

    test('two different wallet ids never block each other', () async {
      final events = <String>[];
      final walletOneEntered = Completer<void>();

      final walletOneCall = BdkFacade.walletLock('wallet-independent-1')
          .synchronized(() async {
            events.add('wallet-one-start');
            walletOneEntered.complete();
            await Future<void>.delayed(const Duration(milliseconds: 20));
            events.add('wallet-one-end');
          });

      await walletOneEntered.future;
      final walletTwoCall = BdkFacade.walletLock('wallet-independent-2')
          .synchronized(() async {
            // Runs to completion well before wallet one's delayed call above
            // — proof the two locks are independent.
            events.add('wallet-two-start');
          });

      await walletTwoCall;
      expect(events, contains('wallet-two-start'));
      expect(events.contains('wallet-one-end'), isFalse);

      await walletOneCall;
    });
  });
}
