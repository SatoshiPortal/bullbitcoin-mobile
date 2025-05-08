import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_address.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_bip329.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_transaction.dart';

class WalletLabels {
  static Future<List<Bip329Label>> txsToBip329(
    List<Transaction> txs,
    String origin,
  ) async {
    return txs
        .where((tx) => tx.label != null)
        .map(
          (tx) => Bip329Label(
            type: BIP329Type.tx,
            ref: tx.txid,
            label: tx.label,
            origin: origin,
          ),
        )
        .toList();
  }

  static Future<List<Bip329Label>> addressesToBip329(
    List<Address> addresses,
    String origin,
  ) async {
    return addresses
        .where((address) => address.label != null)
        .map(
          (address) => Bip329Label(
            type: BIP329Type.address,
            ref: address.address,
            label: address.label,
            spendable: address.spendable,
            origin: origin,
          ),
        )
        .toList();
  }
}
