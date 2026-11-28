import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/presentation/ark_home_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

ArkSnapshot observation(String server, int amount) => ArkSnapshot(
  account: ArkAccountId(
    parent: Fingerprint('1234abcd'),
    network: BitcoinNetwork.regtest,
    serverIdentity: server,
  ),
  revision: 1,
  observedAt: DateTime.utc(2026, 11, 18),
  stale: false,
  spendable: Sats.fromInt(amount),
);

void main() {
  test('reload clears the previous owner before publishing new data', () async {
    final replies = <Completer<ArkSnapshot?>>[];
    final cubit = ArkHomeCubit(() {
      final reply = Completer<ArkSnapshot?>();
      replies.add(reply);
      return reply.future;
    });
    addTearDown(cubit.close);
    var pending = cubit.load();
    replies.last.complete(observation('first', 42));
    await pending;
    expect(cubit.state?.spendable, Sats.fromInt(42));
    pending = cubit.load();
    expect(cubit.state, isNull);
    replies.last.complete(null);
    await pending;
    expect(cubit.state, isNull);
  });

  test(
    'old or disposed dashboard reads never replace the latest observation',
    () async {
      final replies = <Completer<ArkSnapshot?>>[];
      final cubit = ArkHomeCubit(() {
        final reply = Completer<ArkSnapshot?>();
        replies.add(reply);
        return reply.future;
      });
      final first = cubit.load();
      final latest = cubit.load();
      final value = observation('latest', 21);
      replies.last.complete(value);
      await latest;
      replies.first.complete(observation('obsolete', 42));
      await first;
      expect(cubit.state, same(value));
      final pending = cubit.load();
      await cubit.close();
      replies.last.complete(observation('disposed', 100));
      await pending;
      expect(cubit.state, isNull);
    },
  );

  test(
    'a refresh of the same account keeps its balance until it is read',
    () async {
      final replies = <Completer<ArkSnapshot?>>[];
      final cubit = ArkHomeCubit(() {
        final reply = Completer<ArkSnapshot?>();
        replies.add(reply);
        return reply.future;
      });
      addTearDown(cubit.close);
      var pending = cubit.load();
      replies.last.complete(observation('first', 42));
      await pending;
      pending = cubit.load(keep: true);
      // No "unavailable" flash while it is read again.
      expect(cubit.state?.spendable, Sats.fromInt(42));
      replies.last.complete(observation('first', 50));
      await pending;
      expect(cubit.state?.spendable, Sats.fromInt(50));
      // Nothing to show any more is shown as such.
      pending = cubit.load(keep: true);
      replies.last.complete(null);
      await pending;
      expect(cubit.state, isNull);
    },
  );
}
