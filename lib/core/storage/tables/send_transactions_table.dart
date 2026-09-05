// Drift resolves the referenced table from this import when generating the
// raw foreign-key constraint.
// ignore: unused_import
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:drift/drift.dart';

@DataClassName('SendTransactionRow')
@TableIndex(name: 'send_transactions_wallet', columns: {#walletId})
@TableIndex(name: 'send_transactions_updated_at', columns: {#updatedAt})
class SendTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get walletId => text()();
  TextColumn get stage => text()();
  TextColumn get label => text().nullable()();
  TextColumn get recipient => text()();
  TextColumn get amount => text()();
  TextColumn get amountCurrencyCode => text()();
  BoolColumn get sendMax => boolean()();
  TextColumn get feeSelection => text()();
  TextColumn get customFeeKind => text().nullable()();
  IntColumn get customFeeValue => integer().nullable()();
  BoolColumn get replaceByFee => boolean()();
  BoolColumn get payjoinOptedOut =>
      boolean().withDefault(const Constant(false))();
  TextColumn get psbt => text().nullable()();
  TextColumn get finalTransaction => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get revision => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY(wallet_id) REFERENCES wallet_metadatas(id) ON DELETE CASCADE',
    "CHECK(stage IN ('draft', 'needsSignatures', 'readyToBroadcast'))",
    "CHECK(custom_fee_kind IS NULL OR custom_fee_kind IN ('absolute', 'relative'))",
    'CHECK((custom_fee_kind IS NULL) = (custom_fee_value IS NULL))',
    "CHECK(stage = 'draft' OR psbt IS NOT NULL)",
  ];
}

@DataClassName('SendTransactionInputRow')
class SendTransactionInputs extends Table {
  TextColumn get transactionId => text()();
  TextColumn get txId => text()();
  IntColumn get vout => integer()();

  @override
  Set<Column<Object>> get primaryKey => {transactionId, txId, vout};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY(transaction_id) REFERENCES send_transactions(id) ON DELETE CASCADE',
  ];
}

@DataClassName('SendTransactionPolicyChoiceRow')
class SendTransactionPolicyChoices extends Table {
  TextColumn get transactionId => text()();
  TextColumn get node => text()();
  IntColumn get optionIndex => integer()();

  @override
  Set<Column<Object>> get primaryKey => {transactionId, node, optionIndex};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY(transaction_id) REFERENCES send_transactions(id) ON DELETE CASCADE',
  ];
}
