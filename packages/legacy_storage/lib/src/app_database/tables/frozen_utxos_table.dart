import 'package:drift/drift.dart';

@DataClassName('FrozenUtxoRow')
class FrozenUtxos extends Table {
  TextColumn get walletId => text()();
  TextColumn get txId => text()();
  IntColumn get vout => integer()();

  @override
  Set<Column> get primaryKey => {walletId, txId, vout};
}
