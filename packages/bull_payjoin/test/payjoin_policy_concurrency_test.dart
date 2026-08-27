import 'package:bull_payjoin/src/data/payjoin_database.dart';
import 'package:bull_payjoin/src/data/payjoin_policy_store.dart';
import 'package:drift/native.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  test(
    'a stale policy mutation must not restore a concurrently changed field',
    () async {
      final database = PayjoinDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.payjoinPolicies)
          .insert(
            const PayjoinPolicyRow(
              id: 1,
              enabled: true,
              minimumAmountSat: 10000,
              sessionLifetimeSeconds: 86400,
            ),
          );
      final store = PayjoinPolicyStore(database);

      // These snapshots model two public mutations that loaded the same row
      // before either write completed.
      final disableSnapshot = await store.load();
      final minimumSnapshot = await store.load();

      await store.setEnabled(disableSnapshot.copyWith(enabled: false).enabled);
      await store.setMinimumAmount(
        minimumSnapshot
            .copyWith(minimumAmount: Sats.fromInt(20000))
            .minimumAmount,
      );

      final persisted = await store.load();
      expect(
        persisted.enabled,
        isFalse,
        reason: 'changing the minimum must not undo a concurrent disable',
      );
      expect(persisted.minimumAmount, Sats.fromInt(20000));
    },
  );
}
