import 'package:bull_payjoin/src/data/payjoin_database.dart';
import 'package:bull_payjoin/src/domain/payjoin_policy.dart';
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';

final class PayjoinPolicyStore {
  final PayjoinDatabase _database;

  const PayjoinPolicyStore(this._database);

  Future<PayjoinPolicy> load() async {
    final row = await (_database.select(
      _database.payjoinPolicies,
    )..where((row) => row.id.equals(1))).getSingle();
    return _toPolicy(row);
  }

  Stream<PayjoinPolicy> watch() {
    return (_database.select(
      _database.payjoinPolicies,
    )..where((row) => row.id.equals(1))).watchSingle().map(_toPolicy);
  }

  Future<PayjoinPolicy> save(PayjoinPolicy policy) async {
    await (_database.update(
      _database.payjoinPolicies,
    )..where((row) => row.id.equals(1))).write(
      PayjoinPoliciesCompanion(
        sendEnabled: Value(policy.sendEnabled),
        receiveEnabled: Value(policy.receiveEnabled),
        buyEnabled: Value(policy.buyEnabled),
        sellEnabled: Value(policy.sellEnabled),
        minimumAmountSat: Value(policy.minimumAmount.value.toInt()),
        sessionLifetimeSeconds: Value(policy.sessionLifetime.inSeconds),
      ),
    );
    return policy;
  }

  Future<PayjoinPolicy> setActionEnabled(
    PayjoinAction action, {
    required bool enabled,
  }) async {
    final value = Value(enabled);
    await (_database.update(
      _database.payjoinPolicies,
    )..where((row) => row.id.equals(1))).write(switch (action) {
      PayjoinAction.send => PayjoinPoliciesCompanion(sendEnabled: value),
      PayjoinAction.receive => PayjoinPoliciesCompanion(receiveEnabled: value),
      PayjoinAction.buy => PayjoinPoliciesCompanion(buyEnabled: value),
      PayjoinAction.sell => PayjoinPoliciesCompanion(sellEnabled: value),
    });
    return load();
  }

  Future<PayjoinPolicy> setMinimumAmount(Sats amount) async {
    await (_database.update(
      _database.payjoinPolicies,
    )..where((row) => row.id.equals(1))).write(
      PayjoinPoliciesCompanion(minimumAmountSat: Value(amount.value.toInt())),
    );
    return load();
  }

  Future<PayjoinPolicy> setSessionLifetime(Duration lifetime) async {
    await (_database.update(
      _database.payjoinPolicies,
    )..where((row) => row.id.equals(1))).write(
      PayjoinPoliciesCompanion(
        sessionLifetimeSeconds: Value(lifetime.inSeconds),
      ),
    );
    return load();
  }

  PayjoinPolicy _toPolicy(PayjoinPolicyRow row) {
    return PayjoinPolicy(
      sendEnabled: row.sendEnabled,
      receiveEnabled: row.receiveEnabled,
      buyEnabled: row.buyEnabled,
      sellEnabled: row.sellEnabled,
      minimumAmount: Sats.fromInt(row.minimumAmountSat),
      sessionLifetime: Duration(seconds: row.sessionLifetimeSeconds),
    );
  }
}
