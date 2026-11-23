import 'package:bb_mobile/features/swap/data/order_swaps_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'the order owner keeps all request, wallet and transaction indices',
    () async {
      final database = OrderSwapsDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      const indices = <String, (String, bool)>{
        'order_swaps_request_id': ('request_id', true),
        'order_swaps_local_status': ('local_status', false),
        'order_swaps_source_wallet': ('source_wallet_id', false),
        'order_swaps_destination_wallet': ('destination_wallet_id', false),
        'order_swaps_bitcoin_txid': ('bitcoin_transaction_id', false),
        'order_swaps_liquid_txid': ('liquid_transaction_id', false),
        'order_swaps_local_payin_txid': ('local_payin_transaction_id', false),
      };
      final definitions = await database
          .customSelect(
            "SELECT name, \"unique\" FROM pragma_index_list('order_swaps') "
            "WHERE origin = 'c'",
          )
          .get();
      expect(
        definitions.map((r) => r.read<String>('name')),
        unorderedEquals(indices.keys),
      );
      for (final definition in definitions) {
        final name = definition.read<String>('name');
        final metadata = indices[name];
        if (metadata == null) fail('Unexpected index definition');
        final (column, unique) = metadata;
        final columns = await database
            .customSelect("PRAGMA index_info('$name')")
            .get();
        expect(columns.single.read<String>('name'), column);
        expect(definition.read<int>('unique'), unique ? 1 : 0);
      }
    },
  );
}
