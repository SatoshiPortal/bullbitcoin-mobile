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
        enabled: Value(policy.enabled),
        tradingEnabled: Value(policy.tradingEnabled),
        sendEnabled: Value(policy.sendEnabled),
        minimumAmountSat: Value(policy.minimumAmount.value.toInt()),
        sessionLifetimeSeconds: Value(policy.sessionLifetime.inSeconds),
      ),
    );
    return policy;
  }

  Future<PayjoinPolicy> setEnabled(bool enabled) async {
    await (_database.update(_database.payjoinPolicies)
          ..where((row) => row.id.equals(1)))
        .write(PayjoinPoliciesCompanion(enabled: Value(enabled)));
    return load();
  }

  Future<PayjoinPolicy> setTradingEnabled(bool tradingEnabled) async {
    await (_database.update(_database.payjoinPolicies)
          ..where((row) => row.id.equals(1)))
        .write(PayjoinPoliciesCompanion(tradingEnabled: Value(tradingEnabled)));
    return load();
  }

  Future<PayjoinPolicy> setSendEnabled(bool sendEnabled) async {
    await (_database.update(_database.payjoinPolicies)
          ..where((row) => row.id.equals(1)))
        .write(PayjoinPoliciesCompanion(sendEnabled: Value(sendEnabled)));
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
      enabled: row.enabled,
      tradingEnabled: row.tradingEnabled,
      sendEnabled: row.sendEnabled,
      minimumAmount: Sats.fromInt(row.minimumAmountSat),
      sessionLifetime: Duration(seconds: row.sessionLifetimeSeconds),
    );
  }
}
