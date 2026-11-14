import 'dart:async';

import 'package:bb_mobile/features/wallet/data/broadcast_observation_follow_up.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show
        BitcoinBroadcastReceipt,
        BitcoinSpendStatus,
        WalletSpendBlockedFailure,
        WalletSpendFailure;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const _wallet = 'wallet';

/// Records when the follow-up asks for a sync, and how many asks overlap.
final class _Harness {
  final FakeAsync fake;
  final statuses = <Duration>[];
  final polls = <Duration>[];
  final activeChecks = <bool Function()>[];
  Future<BitcoinSpendStatus> Function() status = () async =>
      BitcoinSpendStatus.pending;
  Future<void> Function() poll = () async {};
  var inFlight = 0;
  var maxInFlight = 0;
  late final followUp = BroadcastObservationFollowUp(
    spendStatus: (walletId) {
      statuses.add(fake.elapsed);
      return status();
    },
    pollWallet: (walletId, {required isActive}) async {
      polls.add(fake.elapsed);
      activeChecks.add(isActive);
      inFlight++;
      if (inFlight > maxInFlight) maxInFlight = inFlight;
      try {
        await poll();
      } finally {
        inFlight--;
      }
    },
  );

  _Harness(this.fake);
}

List<Duration> _seconds(List<int> values) => [
  for (final value in values) Duration(seconds: value),
];

void main() {
  test('pending keeps asking at 3, 10, 30 and 90 s, then stops', () {
    fakeAsync((fake) {
      final h = _Harness(fake);
      h.followUp.start(_wallet);
      fake.elapse(const Duration(minutes: 5));
      expect(h.polls, _seconds([3, 10, 30, 90]));
    });
  });

  test('ready ends the follow-up without another sync', () {
    fakeAsync((fake) {
      final h = _Harness(fake);
      final answers = [BitcoinSpendStatus.pending, BitcoinSpendStatus.ready];
      h.status = () async => answers.removeAt(0);
      h.followUp.start(_wallet);
      fake.elapse(const Duration(minutes: 5));
      expect(h.statuses, _seconds([3, 10]));
      expect(h.polls, _seconds([3]));
    });
  });

  test('busy during the initial pass does not stop the follow-up', () {
    fakeAsync((fake) {
      final h = _Harness(fake);
      final answers = [BitcoinSpendStatus.busy, BitcoinSpendStatus.pending];
      h.status = () async =>
          answers.isEmpty ? BitcoinSpendStatus.ready : answers.removeAt(0);
      h.followUp.start(_wallet);
      fake.elapse(const Duration(minutes: 5));
      // Busy at 3 s still asks (pollWallet joins the running pass), and the
      // pending answer at 10 s asks again.
      expect(h.polls, _seconds([3, 10]));
    });
  });

  test('unavailable or a failed attempt is followed by the next one', () {
    fakeAsync((fake) {
      final h = _Harness(fake);
      var call = 0;
      h.status = () async => switch (call++) {
        0 => throw const FormatException('transient'),
        1 => BitcoinSpendStatus.unavailable,
        _ => BitcoinSpendStatus.pending,
      };
      var polls = 0;
      h.poll = () async {
        if (polls++ == 0) throw const SocketExceptionLike();
      };
      h.followUp.start(_wallet);
      fake.elapse(const Duration(minutes: 5));
      expect(h.statuses, _seconds([3, 10, 30, 90]));
      // 3 s: the status read failed, so no sync; 10 s: unavailable still asks
      // (and that ask fails); 30 and 90 s ask normally.
      expect(h.polls, _seconds([10, 30, 90]));
    });
  });

  test('a slow sync skips the deadlines it overran, with no burst', () {
    fakeAsync((fake) {
      final h = _Harness(fake);
      h.poll = () => Future<void>.delayed(const Duration(seconds: 25));
      h.followUp.start(_wallet);
      fake.elapse(const Duration(minutes: 5));
      // The 3 s ask ends at 28 s: 10 s is skipped and 30 s is not advanced.
      expect(h.polls, _seconds([3, 30, 90]));
      expect(h.maxInFlight, 1);
    });
  });

  test('a status read finishing beyond the budget starts no sync', () {
    fakeAsync((fake) {
      final h = _Harness(fake);
      h.status = () => Future<BitcoinSpendStatus>.delayed(
        const Duration(seconds: 100),
        () => BitcoinSpendStatus.pending,
      );
      h.followUp.start(_wallet);
      fake.elapse(const Duration(minutes: 5));
      expect(h.statuses, _seconds([3]));
      expect(h.polls, isEmpty);
    });
  });

  test('a slow read on the last deadline starts no sync after 90 s', () {
    fakeAsync((fake) {
      final h = _Harness(fake);
      h.status = () => fake.elapsed >= const Duration(seconds: 90)
          ? Future<BitcoinSpendStatus>.delayed(
              const Duration(seconds: 1),
              () => BitcoinSpendStatus.pending,
            )
          : Future.value(BitcoinSpendStatus.pending);
      h.followUp.start(_wallet);
      fake.elapse(const Duration(minutes: 5));
      expect(h.statuses, _seconds([3, 10, 30, 90]));
      // The last slot is skipped rather than asking at 91 s.
      expect(h.polls, _seconds([3, 10, 30]));
    });
  });

  test('a new broadcast replaces the follow-up in progress', () {
    fakeAsync((fake) {
      final h = _Harness(fake);
      h.followUp.start(_wallet);
      fake.elapse(const Duration(seconds: 5));
      h.followUp.start(_wallet);
      fake.elapse(const Duration(minutes: 5));
      expect(h.polls, _seconds([3, 8, 15, 35, 95]));
    });
  });

  test('a replacement during the status read stops the old follow-up', () {
    fakeAsync((fake) {
      final h = _Harness(fake);
      final first = Completer<BitcoinSpendStatus>();
      var reads = 0;
      h.status = () => reads++ == 0
          ? first.future
          : Future.value(BitcoinSpendStatus.pending);
      h.followUp.start(_wallet);
      fake.elapse(const Duration(seconds: 3));
      expect(h.statuses, _seconds([3]));
      h.followUp.start(_wallet);
      first.complete(BitcoinSpendStatus.pending);
      fake.elapse(const Duration(minutes: 5));
      // The old follow-up never asks; the new one asks from its own start.
      expect(h.polls, _seconds([6, 13, 33, 93]));
    });
  });

  test('dispose during a sync stops everything and deactivates it', () {
    fakeAsync((fake) {
      final h = _Harness(fake);
      final slow = Completer<void>();
      h.poll = () => slow.future;
      h.followUp.start(_wallet);
      fake.elapse(const Duration(seconds: 3));
      expect(h.polls, _seconds([3]));
      expect(h.activeChecks.single(), isTrue);
      h.followUp.dispose();
      expect(h.activeChecks.single(), isFalse);
      slow.complete();
      fake.elapse(const Duration(minutes: 5));
      expect(h.polls, _seconds([3]));
      h.followUp.start(_wallet);
      fake.elapse(const Duration(minutes: 5));
      expect(h.polls, _seconds([3]));
    });
  });

  group('wrap', () {
    test('an accepted broadcast starts the follow-up, unchanged', () {
      fakeAsync((fake) {
        final h = _Harness(fake);
        var broadcasts = 0;
        const receipt = BitcoinBroadcastReceipt('txid', durable: true);
        final wrapped = h.followUp.wrap((walletId, network, send) async {
          broadcasts++;
          await send();
          return const Ok<BitcoinBroadcastReceipt, WalletSpendFailure>(receipt);
        });
        Result<BitcoinBroadcastReceipt, WalletSpendFailure>? result;
        unawaited(
          wrapped(
            _wallet,
            BitcoinNetwork.testnet,
            () async => 'txid',
          ).then((value) => result = value),
        );
        fake.elapse(const Duration(minutes: 5));
        expect(
          result,
          isA<Ok<BitcoinBroadcastReceipt, WalletSpendFailure>>().having(
            (ok) => ok.value,
            'receipt',
            same(receipt),
          ),
        );
        expect(broadcasts, 1);
        expect(h.polls, _seconds([3, 10, 30, 90]));
      });
    });

    test('a refused broadcast starts nothing', () {
      fakeAsync((fake) {
        final h = _Harness(fake);
        final wrapped = h.followUp.wrap(
          (walletId, network, send) async =>
              const Err<BitcoinBroadcastReceipt, WalletSpendFailure>(
                WalletSpendBlockedFailure(BitcoinSpendStatus.pending),
              ),
        );
        Result<BitcoinBroadcastReceipt, WalletSpendFailure>? result;
        unawaited(
          wrapped(
            _wallet,
            BitcoinNetwork.testnet,
            () async => 'txid',
          ).then((value) => result = value),
        );
        fake.elapse(const Duration(minutes: 5));
        expect(result, isA<Err>());
        expect(h.statuses, isEmpty);
        expect(h.polls, isEmpty);
      });
    });
  });
}

final class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
