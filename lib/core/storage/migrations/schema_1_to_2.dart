import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema1To2 {
  static Future<void> migrate(Migrator m, Schema2 schema2) async {
    // Create AutoSwap table (without recipientWalletId column) and seed it
    await m.createTable(schema2.autoSwap);

    final values = <Insertable<QueryRow>>[
      RawValuesInsertable({
        'id': const Constant(1),
        'enabled': const Constant(true),
        'balance_threshold_sats': const Constant(1000000),
        'fee_threshold_percent': const Constant(3.0),
        'block_till_next_execution': const Constant(false),
        'always_block': const Constant(false),
      }),
      RawValuesInsertable({
        'id': const Constant(2),
        'enabled': const Constant(true),
        'balance_threshold_sats': const Constant(1000000),
        'fee_threshold_percent': const Constant(3.0),
        'block_till_next_execution': const Constant(false),
        'always_block': const Constant(false),
      }),
    ];

    for (final value in values) {
      await m.database.into(schema2.autoSwap).insert(value);
    }
  }
}
