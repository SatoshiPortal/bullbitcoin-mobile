import 'package:drift/drift.dart';

/// Persisted user-frozen wallet outputs (coins).
///
/// A frozen outpoint `(walletId, txId, vout)` is excluded from spending until
/// the user unfreezes it. BDK keeps no frozen flag across restarts
/// (`txBuilder.unspendable()` is ephemeral per-build), so the durable fact
/// "this outpoint is frozen" lives here.
///
/// `walletId` IS the wallet origin (`wallet.id => origin`). It records *which*
/// wallet froze the coin, used for BIP329 export attribution. Exclusion is
/// matched by outpoint (globally unique), not by walletId; a freeze left behind
/// by a deleted wallet is inert (no live coin matches it).
///
/// There is deliberately no freeze-source column: system/payjoin locks are
/// derived live and never persisted here, so every stored row is a user freeze
/// by construction — the "a user can't lift a system lock" contract holds
/// structurally, not by a flag.
@DataClassName('FrozenUtxoRow')
class FrozenUtxos extends Table {
  TextColumn get walletId => text()();
  TextColumn get txId => text()();
  IntColumn get vout => integer()();

  @override
  Set<Column> get primaryKey => {walletId, txId, vout};
}
