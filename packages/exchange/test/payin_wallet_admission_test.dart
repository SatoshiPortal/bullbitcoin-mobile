import 'dart:async';

import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  test('a stale picker callback cannot bind to its successor', () {
    var admission = Object();
    final a1 = admission;
    PayinFromAppWallet choice() {
      final origin = admission;
      return PayinFromAppWallet.witnessed(
        PayinWalletWitness(
          walletId: 'same',
          network: BitcoinNetwork.testnet,
          generation: 3,
          currentReceipt: () => identical(admission, origin) ? origin : null,
        ),
      );
    }

    final old = choice();
    final admitted = old.bindAttempt();
    expect(admitted?.label, isNull);
    expect(admitted?.attempt?.isCurrent, isTrue);
    expect(admitted?.bindAttempt(), isNull);
    admission = Object();
    expect(admission, isNot(same(a1)));
    expect(old.bindAttempt(), isNull);
    expect(admitted?.attempt?.isCurrent, isFalse);
    expect(choice().bindAttempt()?.attempt?.isCurrent, isTrue);
  });

  test('owner waits do not allow new effects after revocation', () async {
    var live = true;
    final attempt = PayinWalletAttempt(
      PayinWalletWitness(
        walletId: 'same',
        network: BitcoinNetwork.testnet,
        generation: 3,
        currentReceipt: () => live ? true : null,
      ),
    );
    final ownerReady = Completer<void>();
    var effects = 0;
    Future<bool> dispatch() async {
      effects++;
      return true;
    }

    Future<bool> owner() async {
      await ownerReady.future;
      return attempt.submit(
        id: 'same',
        network: BitcoinNetwork.testnet,
        generation: 3,
        refused: false,
        dispatch: dispatch,
      );
    }

    final deferred = owner();
    expect(attempt.matches('same', LiquidNetwork.testnet, 3), isFalse);
    expect(attempt.matches('same', BitcoinNetwork.testnet, 4), isFalse);
    live = false;
    ownerReady.complete();
    expect(await deferred, isFalse);
    expect(effects, 0);
  });

  test(
    'late reads are discarded but submitted outcomes are preserved',
    () async {
      final attempt = PayinWalletAttempt(
        PayinWalletWitness(
          walletId: 'same',
          network: BitcoinNetwork.testnet,
          generation: 3,
          currentReceipt: () => true,
        ),
      );
      final response = Completer<String>();
      final pendingRead = attempt.read(
        id: 'same',
        network: BitcoinNetwork.testnet,
        generation: 3,
        load: () => response.future,
      );
      var submissions = 0;
      final result = attempt.submit(
        id: 'same',
        network: BitcoinNetwork.testnet,
        generation: 3,
        refused: 'not sent',
        dispatch: () {
          submissions++;
          return response.future;
        },
      );
      attempt.retire();
      response.complete('unknown');
      expect(await pendingRead, isNull);
      expect(await result, 'unknown');
      expect(submissions, 1);
    },
  );
}
