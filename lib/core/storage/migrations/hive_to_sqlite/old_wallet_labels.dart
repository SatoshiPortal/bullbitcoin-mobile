import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_address.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_bip329.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_transaction.dart';

class WalletLabels {
  static Future<List<OldBip329Label>> txsToBip329(
    List<OldTransaction> txs,
    String origin,
  ) async {
    return txs
        .where((tx) => tx.label != null)
        .map(
          (tx) => OldBip329Label(
            type: OldBIP329Type.tx,
            ref: tx.txid,
            label: tx.label,
            origin: origin,
          ),
        )
        .toList();
  }

  static Future<List<OldBip329Label>> addressesToBip329(
    List<OldAddress> addresses,
    String origin,
  ) async {
    return addresses
        .where((address) => address.label != null)
        .map(
          (address) => OldBip329Label(
            type: OldBIP329Type.address,
            ref: address.address,
            label: address.label,
            spendable: address.spendable,
            origin: origin,
          ),
        )
        .toList();
  }
}
