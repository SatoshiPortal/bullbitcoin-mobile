import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/bip329_label.dart';
import 'package:bb_mobile/_model/transaction.dart';

class WalletLabels {
  Future<List<Bip329Label>> txsToBip329(List<Transaction> txs, String origin) async {
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

  List<Transaction> txsFromBip329(List<Bip329Label> labels) {
    return labels
        .where((label) => label.type == BIP329Type.tx)
        .map(
          (label) => Transaction(
            timestamp: 0,
            txid: label.ref,
            label: label.label,
          ),
        )
        .toList();
  }

  Future<List<Bip329Label>> addressesToBip329(List<Address> addresses, String origin) async {
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

  List<Address> addressesFromBip329(List<Bip329Label> labels) {
    return labels
        .where((label) => label.type == BIP329Type.address)
        .map(
          (label) => Address(
            address: label.ref,
            kind: AddressKind.deposit,
            state: AddressStatus.unused,
            label: label.label,
            spendable: label.spendable ?? true,
          ),
        )
        .toList();
  }
}
