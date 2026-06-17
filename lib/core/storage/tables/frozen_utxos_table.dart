import 'package:drift/drift.dart';

/// Persisted user-frozen wallet outputs (coins).
///
/// A frozen outpoint `(walletId, txId, vout)` is excluded from spending until
/// the user unfreezes it. BDK keeps no frozen flag across restarts
/// (`txBuilder.unspendable()` is ephemeral per-build), so the durable fact
/// "this outpoint is frozen" lives here.
///
/// [origin] records *who* froze the outpoint. This codebase only ever writes
/// `'user'` today; it is forward-compat for the payjoin-unification TODO
/// (rows with `origin = 'payjoin'`) and makes the safety contract explicit:
/// an unfreeze only ever deletes `origin = 'user'` rows, so a user can never
/// unfreeze a system/payjoin lock.
@DataClassName('FrozenUtxoRow')
class FrozenUtxos extends Table {
  TextColumn get walletId => text()();
  TextColumn get txId => text()();
  IntColumn get vout => integer()();
  TextColumn get origin => text().withDefault(const Constant('user'))();

  @override
  Set<Column> get primaryKey => {walletId, txId, vout};
}
