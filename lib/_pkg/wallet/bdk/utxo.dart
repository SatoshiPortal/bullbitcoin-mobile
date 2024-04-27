import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class BDKUtxo {
  Future<(Wallet?, Err?)> loadUtxos({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final unspentList = await bdkWallet.listUnspent();
      final List<Address> myAddresses = wallet.myAddressBook.toList();

      final network = wallet.getBdkNetwork();
      if (network == null) return (null, Err('Network is null'));

      final List<UTXO> list = [];

      for (final unspent in unspentList) {
        UTXO utxo;
        final scr = bdk.ScriptBuf(
          bytes: unspent.txout.scriptPubkey.bytes,
        );
        final addresss = await bdk.Address.fromScript(
          script: scr,
          network: network,
        );
        final addressStr = addresss.toString();
        final AddressKind addressKind =
            unspent.keychain == bdk.KeychainKind.internalChain
                ? AddressKind.change
                : AddressKind.deposit;
        String addressLabel = '';
        bool spendable = true;
        for (final addr in myAddresses) {
          if (addr.address == addressStr) {
            addressLabel = addr.label ?? '';
            spendable = addr.spendable;
          }
        }
        utxo = UTXO(
          txid: unspent.outpoint.txid,
          txIndex: unspent.outpoint.vout,
          isSpent: unspent.isSpent,
          value: unspent.txout.value,
          label: addressLabel,
          spendable: spendable,
          address: Address(
            address: addressStr,
            kind: addressKind,
            state: AddressStatus.active,
          ),
        );
        list.add(utxo);
      }

      final w = wallet.copyWith(utxos: list);
      return (w, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while loading utxos',
          solution: 'Please try again.',
        )
      );
    }
  }

  // Future<(Wallet?, Err? ) updateAddressStates(    required Wallet wallet,
  //   required bdk.Wallet bdkWallet,){

  // }
}
